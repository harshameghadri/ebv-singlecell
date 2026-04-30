# P2 — Multi-Omic: EBV Reprograms Autoreactive B Cells in SLE

Re-analysis of **Younis et al., *Science Translational Medicine* 2025** (DOI: 10.1126/scitranslmed.ady0210).

## Science

EBV+ B cells in SLE are CD27⁺CD21^lo memory cells with ZEB2/TBX21 (T-bet) / APC transcriptional programmes driven directly by EBNA2 binding. The paper introduced a novel EBV detection strategy via composite human+EBV genome alignment and integrates scRNA-seq, EBNA2 ChIP-seq, ATAC-seq, and RNA Pol II occupancy.

This re-analysis independently reproduces the pipeline and adds three extensions not reported in the paper.

## Data

| Assay | Accession |
|---|---|
| All raw SRA (scRNA, ChIP, ATAC, Pol II) | SRA BioProject: PRJNA1301449 |

```bash
# Pull full run manifest first
esearch -db sra -query "PRJNA1301449" | efetch -format runinfo > PRJNA1301449_runinfo.csv
```

**Critical:** All alignment uses a composite GRCh38 + NC_007605.1 (EBV B95-8) reference. Human-only alignment silently discards all viral reads and breaks EBV+ cell identification.

## Analysis plan

### Cluster (SLURM — raw processing)
- [ ] SRA prefetch + fasterq-dump in parallel SLURM array
- [ ] Build composite GRCh38 + NC_007605.1 STAR index (`--genomeSAindexNbases 11`)
- [ ] STARsolo: scRNA-seq alignment → filtered_feature_bc_matrix with EBV feature rows
- [ ] TRUST4: BCR/TCR VDJ assembly from 5' BAMs
- [ ] nf-core/chipseq: EBNA2 + Pol II ChIP-seq pipelines
- [ ] nf-core/atacseq: ATAC-seq pipeline (Tn5 offset correction built in)
- [ ] MultiQC report across all assays

### Local (M1 Max — downstream analysis)
- [ ] Reproduce CD27⁺CD21^lo ZEB2/TBX21 EBV+ B cell phenotype (Seurat)
- [ ] Reproduce EBNA2 binding at CD27/ZEB2/TBX21 TSS (HOMER annotation)
- [ ] Differential chromatin accessibility EBV+ vs EBV− B cells (DiffBind)

### Novel extensions
- [ ] **Pol II pausing index** per EBNA2 target gene (TSS-proximal vs gene-body deepTools signal) — productive elongation vs promoter-proximal pausing not reported in paper
- [ ] **EBV latency programme scoring** per cell: Latency I/II/III by EBNA/LMP transcript profile
- [ ] **BCR clonotype overlap**: do EBV+ clones share CDR3 sequences with ANA-reactive clones? (scRepertoire)

## Output
Integrated multi-omic figure set. Quarto report. If Pol II pausing or latency scoring yield clean signals → candidate for a short data analysis note.

## Stack
STARsolo, TRUST4, Bowtie2, MACS3, HOMER, deepTools, DiffBind, Seurat, Signac, scRepertoire, Nextflow (nf-core), SLURM
