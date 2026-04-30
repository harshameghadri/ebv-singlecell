# EBV Portfolio — CLAUDE.md
**Master agent design, reproducible parameters, and pipeline reference file**
Last updated: 2026-04-30

> This file defines all core decisions, parameters, tool choices, and code templates that remain fixed across sessions.
> When running multiple analysis threads in parallel, this is the authoritative source of truth.
> Update this file when a parameter decision is made — never rely on memory across sessions.

---

## ENVIRONMENT DEFINITIONS

### Cluster (SLURM HPC — 1 month window)
```
Purpose:     Raw SRA download → FASTQ → alignment → BAM → matrices
OS:          Linux (assumed Ubuntu/CentOS)
Scheduler:   SLURM
Workflow:    Nextflow (nf-core) if Singularity+Java11 available; else modular sbatch
Storage:     $SCRATCH — purge FASTQs after alignment, keep BAM + matrices only
Target size: ~50-80 GB final outputs (from ~400-600 GB raw)
```

### Cluster (hpc-rc08)
```
Host:        hpc-rc08
Base path:   /mnt/dzl_bioinf/meghadri/
Projects:    /mnt/dzl_bioinf/meghadri/projects/ebv_temp/
Softwares:   /mnt/dzl_bioinf/meghadri/softwares/
Scheduler:   SLURM
Containers:  Singularity (confirm: singularity --version)

## Installed binaries (confirmed working)
STAR:        /mnt/dzl_bioinf/meghadri/softwares/STAR-2.7.11b/bin/Linux_x86_64_static/STAR
Nextflow:    /mnt/dzl_bioinf/meghadri/softwares/nextflow

## Nextflow — Java proxy fix (run before every nextflow call)
unset _JAVA_OPTIONS
export JAVA_TOOL_OPTIONS="-Dhttp.proxyHost=172.24.2.50 -Dhttp.proxyPort=8080 -Dhttps.proxyHost=172.24.2.50 -Dhttps.proxyPort=8080"
export NXF_OPTS="-Dhttp.proxyHost=172.24.2.50 -Dhttp.proxyPort=8080 -Dhttps.proxyHost=172.24.2.50 -Dhttps.proxyPort=8080"

## fasterq-dump — confirmed flag issue
# --progress is NOT a valid flag — omit it
fasterq-dump ${SRR} --split-files --threads 4 --outdir $OUTDIR

## STAR — do NOT compile from source (simde AVX2 UINT32_C error)
# Use static binary above. No conda, no compilation needed.

Storage:     /mnt/dzl_bioinf/meghadri/ (confirm quota: df -h /mnt/dzl_bioinf/meghadri)
```



### Local (Mac M1 Max)
```
RAM:         64 GB unified memory
GPU:         M1 Max GPU via PyTorch MPS backend (inference only — CONCH/UNI embeddings)
OS:          macOS (ARM64)
R version:   >= 4.3
Python:      via conda-forge (ARM64 native)
Key note:    Cell Ranger NOT available (x86 only) — always use STARsolo
```

---

## REFERENCE GENOME — CANONICAL DEFINITION

**All alignment in this project uses the composite human+EBV reference. No exceptions.**

```bash
# Component 1: Human genome
HUMAN_FASTA="GRCh38.primary_assembly.genome.fa"           # GENCODE v44
HUMAN_GTF="gencode.v44.primary_assembly.annotation.gtf"   # GENCODE v44

# Component 2: EBV genome (B95-8 strain, Type 1)
EBV_FASTA="NC_007605.1.fa"      # NCBI accession NC_007605.1
EBV_GTF="NC_007605.1.gtf"       # Converted from NCBI GFF3 via agat or custom script

# Build composite
cat ${HUMAN_FASTA} ${EBV_FASTA} > GRCh38_EBV.fa
cat ${HUMAN_GTF} ${EBV_GTF} > GRCh38_EBV.gtf

# STAR index — critical flag for small EBV contig
STAR \
  --runMode genomeGenerate \
  --genomeDir /path/to/STAR_GRCh38_EBV_index \
  --genomeFastaFiles GRCh38_EBV.fa \
  --sjdbGTFfile GRCh38_EBV.gtf \
  --genomeSAindexNbases 11 \   # MANDATORY for small contigs
  --runThreadN 16

# Bowtie2 index (ChIP-seq / ATAC-seq)
bowtie2-build GRCh38_EBV.fa GRCh38_EBV_bowtie2
```

**Why this matters:** EBV+ cell identification depends entirely on viral UMI/read counts per barcode. Human-only alignment silently discards all viral reads. Every scRNA-seq, ChIP-seq, and ATAC-seq alignment must use this composite reference.

---

## P1 — scATAC-seq PIPELINE (SoRelle GSE189141)

### Data access
```bash
# Processed matrices — primary analysis (no alignment needed)
wget -c https://ftp.ncbi.nlm.nih.gov/geo/series/GSE189nnn/GSE189141/suppl/GSE189141_RAW.tar

# Zenodo code repository
git clone https://zenodo.org/records/8125208   # or wget via Zenodo API
```

### R environment (Signac-based)
```r
# Core packages — install via renv for reproducibility
packages <- c(
  "Signac",           # scATAC-seq analysis
  "ArchR",            # Alternative/complement to Signac; peak2gene linkage
  "Seurat",           # WNN integration
  "chromVAR",         # TF motif deviation scores
  "BSgenome.Hsapiens.UCSC.hg38",
  "EnsDb.Hsapiens.v86",
  "motifmatchr",
  "JASPAR2020",
  "patchwork",
  "ggplot2"
)
```

### Key analysis parameters
```r
# LSI dimensionality reduction
dims_use <- 2:30                # Exclude PC1 (sequencing depth correlated)
reduction_name <- "lsi"

# UMAP
n.neighbors <- 30
min.dist    <- 0.3

# WNN integration (scATAC + scRNA)
# Use precomputed scRNA embeddings from companion GSE189141 RNA data
weight.reduction <- list(
  atac = "lsi",
  rna  = "pca"
)
dims.atac <- 2:30
dims.rna  <- 1:30

# chromVAR
genome      <- BSgenome.Hsapiens.UCSC.hg38
min.features <- 200

# DAP (differential accessibility)
test.use <- "LR"           # Logistic regression — recommended for scATAC
min.pct  <- 0.05
logfc.threshold <- 0.1
```

### Novel extension: EBV genome ATAC
```bash
# After standard alignment, extract reads mapping to EBV contig
samtools view -b aligned.bam "NC_007605.1" > ebv_reads.bam
samtools index ebv_reads.bam
# Visualise coverage with deepTools
bamCoverage -b ebv_reads.bam -o ebv_coverage.bw --normalizeUsing CPM
```

---

## P2 — SLE MULTI-OMIC PIPELINE (Younis PRJNA1301449)

### SRA download (cluster)
```bash
# Step 1: Pull full run manifest
esearch -db sra -query "PRJNA1301449" | \
  efetch -format runinfo > PRJNA1301449_runinfo.csv

# Step 2: Parallel prefetch (submit as SLURM array)
prefetch ${SRR_ID} --output-directory $SCRATCH/sra_cache
fasterq-dump $SCRATCH/sra_cache/${SRR_ID} \
  --split-files --threads 8 \
  --outdir $SCRATCH/fastq/${SRR_ID}

# Step 3: DELETE .sra cache after FASTQ extraction to save space
rm -rf $SCRATCH/sra_cache/${SRR_ID}
```

### scRNA-seq: STARsolo (NOT Cell Ranger)
```bash
STAR=/mnt/dzl_bioinf/meghadri/softwares/STAR-2.7.11b/bin/Linux_x86_64_static/STAR
# Cell Ranger is x86-only — STARsolo is the drop-in replacement
STAR \
  --soloType CB_UMI_Simple \
  --soloCBwhitelist 3M-february-2018.txt \   # 10x v3 whitelist
  --soloCBstart 1 --soloCBlen 16 \
  --soloUMIstart 17 --soloUMIlen 12 \
  --genomeDir /path/to/STAR_GRCh38_EBV_index \
  --readFilesIn R2.fastq.gz R1.fastq.gz \   # Note: R2 first for 10x 5'
  --readFilesCommand zcat \
  --outSAMtype BAM SortedByCoordinate \
  --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
  --runThreadN 16 \
  --outFileNamePrefix $SCRATCH/aligned/scrna/${SAMPLE}/

# EBV+ cell identification: barcodes with viral feature UMI count > threshold
# Extract from STARsolo matrix — EBV genes are rows with "NC_007605.1" prefix
```

### BCR/TCR: TRUST4
```bash
# Run from BAM (no separate VDJ library needed if 5' capture)
run-trust4 \
  -b ${SAMPLE}_Aligned.sortedByCoord.out.bam \
  -f hg38_bcrtcr.fa \                # TRUST4 reference
  --ref human_IMGT+C.fa \
  --barcode CB \                     # 10x cell barcode tag
  --UMI UB \                         # UMI tag
  -o $SCRATCH/trust4/${SAMPLE}/

# Output: ${SAMPLE}_final.out — barcode-level CDR3 sequences
# Load into R with scRepertoire::loadContigs()
```

### ChIP-seq (EBNA2 + Pol II): nf-core/chipseq
```bash
# nf-core/chipseq v2.x samplesheet format:
# sample,fastq_1,fastq_2,antibody,control
# EBNA2_rep1,R1.fq.gz,R2.fq.gz,EBNA2,INPUT_rep1

nextflow run nf-core/chipseq \
  -profile singularity \
  --input samplesheet_chipseq.csv \
  --genome custom \
  --fasta GRCh38_EBV.fa \
  --gtf GRCh38_EBV.gtf \
  --bowtie2 GRCh38_EBV_bowtie2 \
  --macs_gsize 2.9e9 \
  --outdir $SCRATCH/chipseq_results/
```

### ATAC-seq: nf-core/atacseq
```bash
# Key difference from ChIP: Tn5 offset correction (+4/-5 bp) handled by pipeline
nextflow run nf-core/atacseq \
  -profile singularity \
  --input samplesheet_atacseq.csv \
  --genome custom \
  --fasta GRCh38_EBV.fa \
  --gtf GRCh38_EBV.gtf \
  --bowtie2 GRCh38_EBV_bowtie2 \
  --outdir $SCRATCH/atacseq_results/
```

### Novel extension: Pol II pausing index
```bash
# Per EBNA2 target gene: TSS-proximal signal / gene body signal
# Uses deepTools multiBamSummary + custom R script

# Step 1: Generate coverage bigWigs (already done by nf-core/chipseq)
# Step 2: Compute signal in TSS windows (±300 bp) and gene body (300bp → TES)
computeMatrix reference-point \
  --referencePoint TSS \
  -b 300 -a 300 \
  -S PolII_rep1.bw PolII_rep2.bw \
  -R EBNA2_target_genes.bed \
  -o TSS_matrix.gz

computeMatrix scale-regions \
  -S PolII_rep1.bw PolII_rep2.bw \
  -R EBNA2_target_genes.bed \
  --regionBodyLength 2000 \
  --skipZeros \
  -o genebody_matrix.gz

# Pausing Index = mean(TSS signal) / mean(gene body signal) per gene
# Implement in R: read matrices, compute per-row ratios, annotate by EBNA2 binding
```

---

## P3 — DLBCL SPATIAL PIPELINE

### Primary dataset: HIV-NHL Visium (GSE274051)
```bash
# Download via GEO FTP
wget -c https://ftp.ncbi.nlm.nih.gov/geo/series/GSE274nnn/GSE274051/suppl/GSE274051_RAW.tar
```

### Secondary dataset: IN-DEPTH paper (Zenodo)
```bash
# Zenodo API download (browser unreliable)
for RECORD in 14639480 18379156; do
  curl -s https://zenodo.org/api/records/${RECORD} \
    | python3 -c "
import sys, json
record = json.load(sys.stdin)
for f in record['files']:
    url = f['links']['self']
    name = f['key']
    import subprocess
    subprocess.run(['wget', '-c', '--progress=bar', '-O', name, url])
"
done
```

### Seurat spatial pipeline
```r
library(Seurat)
library(ggplot2)
library(patchwork)

# Load Visium data (spaceranger output)
load_visium_sample <- function(sample_path, sample_name) {
  obj <- Load10X_Spatial(
    data.dir = sample_path,
    filename = "filtered_feature_bc_matrix.h5",
    assay = "Spatial",
    filter.matrix = TRUE
  )
  obj$sample <- sample_name
  return(obj)
}

# QC parameters (spatial)
min_counts_per_spot <- 500
min_genes_per_spot  <- 300
max_pct_mt          <- 25       # Higher threshold than scRNA-seq

# Normalisation
obj <- SCTransform(obj, assay = "Spatial", verbose = FALSE)

# Spatially variable features
obj <- FindSpatiallyVariableFeatures(
  obj,
  assay = "SCT",
  selection.method = "moransi",
  n = 3000
)
```

### EBV latency programme scoring
```r
# Define latency gene signatures (from published literature)
latency_I_genes   <- c("EBNA1")                              # EBER1/2 not in probe panel
latency_II_genes  <- c("LMP1", "LMP2A", "LMP2B", "EBNA1")
latency_III_genes <- c("EBNA1", "EBNA2", "EBNA3A", "EBNA3B", "EBNA3C",
                        "EBNALP", "LMP1", "LMP2A", "LMP2B")

# Use host downstream targets as proxy (EBV genes often low/absent in Visium)
# LMP1 downstream: CD54/ICAM1, CD40, CD80, A20/TNFAIP3, CCL3, CCL4
# EBNA2 downstream: CD21/CR2, CD23/FCER2, CD39/ENTPD1, CCR7

lmp1_downstream  <- c("ICAM1", "CD40", "CD80", "TNFAIP3", "CCL3", "CCL4", "CXCL10")
ebna2_downstream <- c("CR2", "FCER2", "ENTPD1", "CCR7", "MYC", "CCND2")

obj <- AddModuleScore(obj,
  features = list(lmp1_downstream, ebna2_downstream),
  name = c("LMP1_programme", "EBNA2_programme"),
  assay = "SCT"
)
```

### Neighbourhood enrichment (reuse from spatial work experience)
```r
library(dbscan)

# frNN radius graph — analogous to squidpy sq.gr.nhood_enrichment
run_nhood_enrichment <- function(coords, labels, radius = 100, n_perms = 1000) {
  # coords: Nx2 matrix of spot coordinates
  # labels: factor of cell type assignments per spot
  rnn   <- frNN(coords, eps = radius)
  n_ct  <- nlevels(labels)
  ct    <- levels(labels)
  obs   <- matrix(0, n_ct, n_ct, dimnames = list(ct, ct))

  for (i in seq_along(rnn$id)) {
    if (length(rnn$id[[i]]) == 0) next
    l_i <- as.integer(labels[i])
    for (j in rnn$id[[i]]) {
      l_j <- as.integer(labels[j])
      obs[l_i, l_j] <- obs[l_i, l_j] + 1
    }
  }

  # Permutation test
  perm_counts <- array(0, dim = c(n_ct, n_ct, n_perms))
  for (p in seq_len(n_perms)) {
    perm_labels <- sample(labels)
    perm_mat    <- matrix(0, n_ct, n_ct)
    for (i in seq_along(rnn$id)) {
      if (length(rnn$id[[i]]) == 0) next
      l_i <- as.integer(perm_labels[i])
      for (j in rnn$id[[i]]) {
        l_j <- as.integer(perm_labels[j])
        perm_mat[l_i, l_j] <- perm_mat[l_i, l_j] + 1
      }
    }
    perm_counts[,,p] <- perm_mat
  }

  z_scores <- (obs - apply(perm_counts, 1:2, mean)) /
              (apply(perm_counts, 1:2, sd) + 1e-9)
  list(observed = obs, z_scores = z_scores)
}
```

### TCGA-DLBC: RNA-seq + EBV detection
```r
library(TCGAbiolinks)

# Pull TCGA-DLBC RNA-seq count matrices
query <- GDCquery(
  project      = "TCGA-DLBC",
  data.category = "Transcriptome Profiling",
  data.type    = "Gene Expression Quantification",
  workflow.type = "STAR - Counts"
)
GDCdownload(query)
data <- GDCprepare(query)

# EBV+ case identification from RNA-seq:
# 1. Download raw BAMs (or use existing STAR unmapped reads)
# 2. Align unmapped reads to EBV genome
# 3. Normalise viral read count by total mapped reads (RPM)
# 4. EBV+ threshold: RPM > 0.1 (validated in TCGA-STAD literature)

# Alternatively: use pre-computed viral expression from published TCGA viral surveys
```

### TCGA WSI slides: gdc-client download
```bash
# 1. Go to https://portal.gdc.cancer.gov
# 2. Filter: Project=TCGA-DLBC, Data Type=Slide Image, Experimental Strategy=Diagnostic Slide
# 3. Download manifest.txt
# 4. Download slides:
gdc-client download \
  -m gdc_manifest_TCGADLBC_slides.txt \
  -d $SCRATCH/tcga_dlbc_slides/ \
  --n-processes 4

# Expected: ~48 slides × 0.5-2 GB = ~60-80 GB
# File naming: DX = FFPE diagnostic slide (use these); TS/BS = frozen (skip)
```

### Foundation model embeddings (M1 GPU)
```python
# CONCH or UNI from HuggingFace — inference only, no fine-tuning
import torch
from PIL import Image
from tiatoolbox.wsicore.wsireader import WSIReader

device = "mps"   # Apple Silicon GPU via MPS backend

# Patch extraction
reader = WSIReader.open("slide.svs")
patches = reader.read_bounds(
    (x, y, x+256, y+256),
    resolution=20,    # 20x magnification
    units="power"
)

# CONCH embedding
# model = load from HuggingFace MahmoodLab/conch
# embeddings = model.encode(patches)  — no gradient needed
with torch.no_grad():
    embeddings = model(patches.to(device)).cpu().numpy()

# Store as HDF5 per slide
import h5py
with h5py.File(f"{slide_id}_embeddings.h5", "w") as f:
    f.create_dataset("embeddings", data=embeddings)
    f.create_dataset("coords", data=patch_coords)
```

---

## CLUSTER DIRECTORY STRUCTURE (canonical)
```
$SCRATCH/ebv_sle_pipeline/
├── 00_sra_metadata/          # runinfo CSV, SRA metadata tables
├── 01_references/            # GRCh38+EBV FASTA, GTF, STAR index, Bowtie2 index
├── 02_fastq/                 # TEMPORARY — delete after alignment
├── 03_aligned/               # BAMs (keep)
│   ├── scrna/
│   ├── chipseq_ebna2/
│   ├── chipseq_polii/
│   └── atacseq/
├── 04_matrices/              # STARsolo output (keep, transfer to local)
├── 05_peaks/                 # MACS3 narrowPeak + broadPeak (keep)
├── 06_bigwigs/               # deepTools normalised tracks (keep)
├── 07_trust4/                # VDJ assemblies (keep)
├── logs/
└── nextflow_work/            # Purge after successful pipeline completion
```

---

## CLUSTER ENVIRONMENT CHECK (run before anything else)
```bash
# Nextflow
which nextflow && nextflow -version
java -version

# Containers
which singularity && singularity --version
# or
which docker && docker --version

# SLURM
sinfo
scontrol show config | grep -i "ClusterName"

# Storage quota
df -h $SCRATCH
```

---

## SUCCESS CRITERIA (pipeline complete when ALL met)

| Assay | Done when |
|---|---|
| scRNA-seq | `filtered_feature_bc_matrix/` per sample; EBV feature rows present in matrix |
| BCR/TCR | TRUST4 `_final.out` per sample with barcode-level CDR3 |
| ChIP EBNA2 | Sorted deduped BAMs + MACS3 narrowPeak + bigWigs per replicate |
| ATAC-seq | Sorted deduped BAMs + MACS3 narrowPeak (shifted) + bigWigs |
| Pol II ChIP | BAMs + bigWigs + pausing index TSV per gene |
| QC | MultiQC report covering all assays passes visual inspection |
| Transfer | All matrices + peaks + bigWigs rsync'd to local Mac |

---

## CONTEXT MANAGEMENT PROTOCOL

When conversation approaches 20k-25k tokens, Claude will prompt:

> *"We're approaching context limits. Please summarise: (1) any new code/parameters to add to claude.md, (2) progress updates for project.md, (3) any new datasets or accessions to log."*

Files to update at each checkpoint:
- **claude.md** — new code snippets, parameter decisions, tool version pins
- **project.md** — progress updates, completed milestones, new ideas, download status
- Create **notes_YYYY-MM-DD.md** for session-specific scratch notes if needed
