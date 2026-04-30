# P1 — scATAC-seq: EBV Chromatin Landscapes

Replication and extension of **SoRelle et al., *Cell Reports* 2023** (DOI: 10.1016/j.celrep.2023.112958).

## Science

EBV+ B cells partition into two major states after primary infection:
- **Arrested cells** — antiviral sensing, global chromatin closure
- **Proliferative cells** — GC-like accessibility (DZ/LZ/post-GC chromatin signatures) without BCL6 expression

The proliferative state includes a TBX21⁺CXCR3⁺ ABC-like niche relevant to EBV-associated autoimmunity. This project replicates the original findings and adds extensions not present in the paper.

## Data

| Resource | Accession / URL |
|---|---|
| Processed matrices (MTX/TSV/BIGWIG) | GEO: GSE189141 |
| Companion scRNA-seq (same experiment) | GEO: GSE189141 / SRA: SRP346796 |
| Original analysis code | Zenodo: https://zenodo.org/records/8125208 |

Download:
```bash
wget -c https://ftp.ncbi.nlm.nih.gov/geo/series/GSE189nnn/GSE189141/suppl/GSE189141_RAW.tar
```

## Analysis plan

### Replication
- [ ] QC: TSS enrichment, fragment size distribution, nucleosome signal
- [ ] LSI dimensionality reduction → WNN integration with scRNA-seq → UMAP
- [ ] Reproduce EBV+high-ATAC / EBV+low-ATAC / uninfected cluster partitioning
- [ ] DAP analysis: lymphocyte activation / defense response GO terms
- [ ] chromVAR TF motif deviation: BACH2, IRF4, PRDM1 enrichment per cluster

### Novel extensions
- [ ] Map ATAC reads to EBV genome (NC_007605.1) per cell state — viral promoter accessibility
- [ ] ArchR peak2gene linkage at BCL2 / MCL1 / BCL2A1 loci
- [ ] Pseudotime of chromatin opening events (kinetics of GC programme engagement)
- [ ] EBNA2 ChIP peak overlap quantification per DAP per cell state

## Output
Quarto HTML report with side-by-side replication panels + extension figures. Hosted on GitHub Pages.

## Stack
R, Signac, ArchR, chromVAR, MACS2, BSgenome.Hsapiens.UCSC.hg38, Seurat WNN, Quarto
