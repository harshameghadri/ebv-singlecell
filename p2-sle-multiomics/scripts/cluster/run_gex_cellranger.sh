#!/bin/bash
# =============================================================================
# GEX Pipeline: Cell Ranger count → TRUST4 per sample
# hpc-rc08 | 24 threads | no SLURM — run in tmux
# =============================================================================
#
# USAGE:
#   bash run_gex_cellranger.sh [OPTIONS]
#
# OPTIONS:
#   --samples HC1,HC2,HC4     Only process these samples (comma-separated)
#   --continue-trust4         Skip Cell Ranger, run TRUST4 on existing BAMs only
#   --skip-trust4             Run Cell Ranger only, skip TRUST4
#   --trust4-only SAMPLE      Run TRUST4 on one sample's BAM then delete it
#   --dry-run                 Print what would run without executing anything
#
# EXAMPLES:
#   bash run_gex_cellranger.sh                          # full pipeline all samples
#   bash run_gex_cellranger.sh --continue-trust4        # resume TRUST4 after failure
#   bash run_gex_cellranger.sh --samples HC2,HC4        # specific samples only
#   bash run_gex_cellranger.sh --dry-run                # preview without running
# =============================================================================

set -euo pipefail

# =============================================================================
# DEFAULTS
# =============================================================================
CELLRANGER=/mnt/dzl_bioinf/meghadri/softwares/cellranger-10.0.0/cellranger
TRUST4_DIR=/mnt/dzl_bioinf/meghadri/softwares/TRUST4
BASE=/mnt/dzl_bioinf/meghadri/projects/ebv_temp

TRANSCRIPTOME="${BASE}/01_references/GRCh38_EBV"
FASTQ_DIR="${BASE}/02_fastq/gex"
MATRIX_DIR="${BASE}/04_matrices"
TRUST4_OUT="${BASE}/07_trust4"
LOGS="${BASE}/05_logs"

TRUST4_BCR="${TRUST4_DIR}/hg38_bcrtcr.fa"
TRUST4_IMGT="${TRUST4_DIR}/human_IMGT+C.fa"

THREADS=24
MEMGB=300

# Mode flags
MODE_CONTINUE_TRUST4=0   # --continue-trust4
MODE_SKIP_TRUST4=0       # --skip-trust4
MODE_DRY_RUN=0           # --dry-run
SAMPLE_FILTER=""         # --samples HC1,HC2,...

# All samples in order
ALL_SAMPLES=(HC1 HC2 HC4 HC6 HC7 HC8c HC9 HC10 SLE1 SLE2b SLE3 SLE4 SLE4p SLE6 SLE7 SLE8b SLE9)

# SRR→sample mapping
declare -A SAMPLE_SRR
SAMPLE_SRR[HC1]=SRR35978585
SAMPLE_SRR[HC2]=SRR35978530
SAMPLE_SRR[HC4]=SRR35978584
SAMPLE_SRR[HC6]=SRR35978578
SAMPLE_SRR[HC7]=SRR35978576
SAMPLE_SRR[HC8c]=SRR35978570
SAMPLE_SRR[HC9]=SRR35978567
SAMPLE_SRR[HC10]=SRR35978552
SAMPLE_SRR[SLE1]=SRR35978565
SAMPLE_SRR[SLE2b]=SRR35978554
SAMPLE_SRR[SLE3]=SRR35978551
SAMPLE_SRR[SLE4]=SRR35978549
SAMPLE_SRR[SLE4p]=SRR35978545
SAMPLE_SRR[SLE6]=SRR35978539
SAMPLE_SRR[SLE7]=SRR35978537
SAMPLE_SRR[SLE8b]=SRR35978532
SAMPLE_SRR[SLE9]=SRR35978528

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --continue-trust4)
            MODE_CONTINUE_TRUST4=1
            shift ;;
        --skip-trust4)
            MODE_SKIP_TRUST4=1
            shift ;;
        --dry-run)
            MODE_DRY_RUN=1
            shift ;;
        --samples)
            SAMPLE_FILTER="${2:-}"
            if [ -z "${SAMPLE_FILTER}" ]; then
                echo "ERROR: --samples requires a comma-separated list."
                exit 1
            fi
            shift 2 ;;
        --trust4-only)
            # Convenience: run TRUST4 on a single named sample and exit
            SINGLE="${2:-}"
            if [ -z "${SINGLE}" ]; then
                echo "ERROR: --trust4-only requires a sample name."
                exit 1
            fi
            BAM="${MATRIX_DIR}/${SINGLE}/outs/possorted_genome_bam.bam"
            if [ ! -f "${BAM}" ]; then
                echo "ERROR: BAM not found for ${SINGLE} at ${BAM}"
                exit 1
            fi
            mkdir -p "${TRUST4_OUT}/${SINGLE}"
            echo "Running TRUST4 for ${SINGLE}..."
            "${TRUST4_DIR}/run-trust4" \
                -b "${BAM}" \
                -f "${TRUST4_BCR}" \
                --ref "${TRUST4_IMGT}" \
                --barcode CB \
                --UMI UB \
                -t "${THREADS}" \
                -o "${TRUST4_OUT}/${SINGLE}/${SINGLE}" \
                2>&1 | tee "${TRUST4_OUT}/${SINGLE}/${SINGLE}_trust4.log" && \
            echo "TRUST4 done. Deleting BAM..." && \
            rm -f "${BAM}" "${BAM}.bai" && \
            echo "Done." || echo "WARNING: TRUST4 failed — BAM preserved"
            exit 0 ;;
        --help|-h)
            head -25 "$0" | grep "^#" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "Unknown option: $1. Use --help for usage."
            exit 1 ;;
    esac
done

# Build active sample list
if [ -n "${SAMPLE_FILTER}" ]; then
    IFS=',' read -ra SAMPLES <<< "${SAMPLE_FILTER}"
else
    SAMPLES=("${ALL_SAMPLES[@]}")
fi

# =============================================================================
# HELPERS
# =============================================================================
run_or_dry() {
    if [ "${MODE_DRY_RUN}" -eq 1 ]; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

diskfree() {
    df -h "${BASE}" | awk 'NR==2{print $4}' || echo "unknown"
}

# =============================================================================
# PRE-FLIGHT
# =============================================================================
echo "=== Pre-flight checks ==="
echo "  Mode: $([ "${MODE_CONTINUE_TRUST4}" -eq 1 ] && echo 'continue-trust4' || echo 'full pipeline')"
echo "  Dry run: $([ "${MODE_DRY_RUN}" -eq 1 ] && echo YES || echo no)"
echo "  Samples: ${SAMPLES[*]}"

if [ ! -d "${TRANSCRIPTOME}" ]; then
    echo "ERROR: Transcriptome not found at ${TRANSCRIPTOME}"
    exit 1
fi

SKIP_TRUST4=${MODE_SKIP_TRUST4}
for REF in "${TRUST4_BCR}" "${TRUST4_IMGT}"; do
    if [ ! -f "${REF}" ]; then
        echo "WARNING: TRUST4 reference missing: ${REF}"
        SKIP_TRUST4=1
    fi
done

mkdir -p "${MATRIX_DIR}" "${TRUST4_OUT}" "${LOGS}"
echo "  Disk free: $(diskfree)"
echo "=== Pre-flight OK ==="

# =============================================================================
# TRUST4 FUNCTION — reused in both modes
# =============================================================================
run_trust4() {
    local SAMPLE="$1"
    local BAM="$2"
    local OUT_TRUST="${TRUST4_OUT}/${SAMPLE}"

    if [ "${SKIP_TRUST4}" -eq 1 ]; then
        echo "  [TRUST4] Skipped — references missing or --skip-trust4 set. BAM preserved."
        return 0
    fi

    mkdir -p "${OUT_TRUST}"
    echo "  [TRUST4] Running for ${SAMPLE}..."

    if run_or_dry "${TRUST4_DIR}/run-trust4" \
        -b "${BAM}" \
        -f "${TRUST4_BCR}" \
        --ref "${TRUST4_IMGT}" \
        --barcode CB \
        --UMI UB \
        -t "${THREADS}" \
        -o "${OUT_TRUST}/${SAMPLE}" \
        2>&1 | tee "${OUT_TRUST}/${SAMPLE}_trust4.log"; then

        echo "  [TRUST4] Done. Deleting BAM..."
        run_or_dry rm -f "${BAM}" "${BAM}.bai"
        echo "  [TRUST4] BAM deleted. Disk free: $(diskfree)"
    else
        echo "  [TRUST4] WARNING: Failed for ${SAMPLE} — BAM preserved at ${BAM}"
    fi
}

# =============================================================================
# --continue-trust4 MODE: run TRUST4 on all existing BAMs, skip Cell Ranger
# =============================================================================
if [ "${MODE_CONTINUE_TRUST4}" -eq 1 ]; then
    echo ""
    echo "=== CONTINUE-TRUST4 MODE ==="
    for SAMPLE in "${SAMPLES[@]}"; do
        BAM="${MATRIX_DIR}/${SAMPLE}/outs/possorted_genome_bam.bam"
        TRUST4_DONE="${TRUST4_OUT}/${SAMPLE}/${SAMPLE}_barcode_report.tsv"

        if [ ! -f "${BAM}" ]; then
            echo "  SKIP: ${SAMPLE} — no BAM found"
            continue
        fi
        if [ -f "${TRUST4_DONE}" ]; then
            echo "  SKIP: ${SAMPLE} — TRUST4 already complete"
            continue
        fi
        echo ""
        echo "  Processing TRUST4: ${SAMPLE} | $(date) | Disk: $(diskfree)"
        run_trust4 "${SAMPLE}" "${BAM}"
        echo "  === ${SAMPLE} TRUST4 COMPLETE ==="
    done
    echo ""
    echo "=== CONTINUE-TRUST4 COMPLETE ==="
    exit 0
fi

# =============================================================================
# FULL PIPELINE MODE
# =============================================================================
for SAMPLE in "${SAMPLES[@]}"; do

    FQDIR="${FASTQ_DIR}/${SAMPLE}"
    SRR="${SAMPLE_SRR[$SAMPLE]:-}" # Fallback if SAMPLE isn't in mapping array
    OUT_DIR="${MATRIX_DIR}/${SAMPLE}"
    BAM="${OUT_DIR}/outs/possorted_genome_bam.bam"

    # Skip if no FASTQs and no existing BAM to process
    HAVE_FASTQ=0
    if [ -d "${FQDIR}" ] && ls "${FQDIR}"/*.fastq.gz >/dev/null 2>&1; then
        HAVE_FASTQ=1
    fi

    HAVE_MATRIX=0
    if [ -d "${OUT_DIR}/outs/filtered_feature_bc_matrix" ]; then
        HAVE_MATRIX=1
    fi

    if [ "${HAVE_FASTQ}" -eq 0 ] && [ "${HAVE_MATRIX}" -eq 0 ]; then
        echo "  SKIP: ${SAMPLE} — no FASTQs and no existing matrix"
        continue
    fi

    echo ""
    echo "============================================================"
    echo "  Processing : ${SAMPLE} (${SRR})"
    echo "  $(date) | Disk free: $(diskfree)"
    echo "============================================================"

    # --- Cell Ranger (skip if matrix exists) ---------------------------------
    if [ "${HAVE_MATRIX}" -eq 1 ]; then
        echo "  [CR] Matrix exists — skipping Cell Ranger"
    elif [ "${HAVE_FASTQ}" -eq 1 ]; then

        # Rename SRA FASTQs to 10x format if needed
        for READ in 1 2; do
            OLD="${FQDIR}/${SRR}_${READ}.fastq.gz"
            NEW="${FQDIR}/${SRR}_S1_L001_R${READ}_001.fastq.gz"
            if [ -f "${OLD}" ] && [ ! -f "${NEW}" ]; then
                echo "  Renaming: $(basename "${OLD}") → $(basename "${NEW}")"
                run_or_dry mv "${OLD}" "${NEW}"
            fi
        done

        echo "  [CR] Running cellranger count..."
        cd "${MATRIX_DIR}" || exit 1

        if run_or_dry "${CELLRANGER}" count \
            --id="${SAMPLE}" \
            --transcriptome="${TRANSCRIPTOME}" \
            --fastqs="${FQDIR}" \
            --sample="${SRR}" \
            --chemistry=fiveprime \
            --localcores="${THREADS}" \
            --localmem="${MEMGB}" \
            --create-bam=true \
            2>&1 | tee "${LOGS}/${SAMPLE}_cellranger.log"; then
            echo "  [CR] Done."
        else
            echo "  ERROR: Cell Ranger FAILED for ${SAMPLE} — skipping to next sample"
            continue
        fi

        if [ ! -f "${BAM}" ] && [ "${MODE_DRY_RUN}" -eq 0 ]; then
            echo "  ERROR: BAM not found after Cell Ranger — skipping ${SAMPLE}"
            continue
        fi

        echo "  Deleting FASTQs for ${SAMPLE}..."
        run_or_dry rm -rf "${FQDIR}/"
        echo "  FASTQs deleted. Disk free: $(diskfree)"
    fi

    # --- TRUST4 ---------------------------------------------------------------
    TRUST4_DONE="${TRUST4_OUT}/${SAMPLE}/${SAMPLE}_barcode_report.tsv"
    if [ -f "${TRUST4_DONE}" ]; then
        echo "  [TRUST4] Already complete — skipping"
    else
        run_trust4 "${SAMPLE}" "${BAM}"
    fi

    echo "  === ${SAMPLE} COMPLETE at $(date) ==="

done

echo ""
echo "============================================================"
echo "  ALL AVAILABLE SAMPLES COMPLETE"
echo "  Matrices : ${MATRIX_DIR}"
echo "  TRUST4   : ${TRUST4_OUT}"
echo "  $(date)"
echo "============================================================"
