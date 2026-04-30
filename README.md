# EBV Single-Cell & Spatial Portfolio

Computational re-analysis of publicly available Epstein-Barr virus (EBV) datasets spanning primary infection, autoimmunity, and lymphoma. Purely computational — no wet lab, no novel experiments.

## Unifying narrative

> EBV hijacks a conserved **TBX21⁺CXCR3⁺ atypical B cell (ABC) programme** across primary infection, autoimmunity, and malignancy.

This thread connects all three projects and serves as the basis for a potential integrated bioRxiv paper.

---

## Projects

### [P1 — scATAC-seq: EBV Chromatin Landscapes](./p1-scrna-atac/)
Replication and extension of SoRelle et al. *Cell Reports* 2023. Maps chromatin accessibility dynamics in primary B cells during EBV infection, integrating scATAC-seq, scRNA-seq, and ChIP-seq. Novel extensions include EBV genome accessibility mapping and peak-to-gene linkage at anti-apoptotic loci.

**Data:** GEO GSE189141 | **Stack:** R, Signac, ArchR, chromVAR, Seurat WNN

---

### [P2 — Multi-Omic: EBV Reprograms Autoreactive B Cells in SLE](./p2-sle-multiomics/)
Re-analysis of Younis et al. *Sci. Transl. Med.* 2025 (PRJNA1301449). Processes raw SRA data through a composite human+EBV reference pipeline covering scRNA-seq, BCR/TCR repertoire, EBNA2 ChIP-seq, ATAC-seq, and RNA Pol II occupancy. Novel extensions include Pol II pausing index and EBV latency programme scoring per cell.

**Data:** SRA PRJNA1301449 | **Stack:** STARsolo, TRUST4, Bowtie2, MACS3, deepTools, Seurat, Signac, scRepertoire

---

### [P3 — Spatial: EBV+ DLBCL Tumour Microenvironment](./p3-dlbcl-spatial/)
Spatial transcriptomics re-analysis of EBV+ vs EBV− DLBCL using HIV-NHL Visium data (GSE274051, 10 samples / 5 EBV+) and the IN-DEPTH spatial multi-omics dataset (VisiumHD + GeoMx + CODEX, PMC11702642). Supplemented by TCGA-DLBC computational pathology using foundation model patch embeddings (CONCH/UNI) on H&E slides.

**Data:** GEO GSE274051, Zenodo 14639480/18379156, TCGA-DLBC GDC | **Stack:** Seurat spatial, Squidpy, RCTD, CellChat, dbscan, TIAToolbox, PyTorch MPS

---

## Repository structure

```
ebv-singlecell/
├── project.md              # Master progress, ideas, and chain-of-thought log
├── claude.md               # Reproducible parameters, pipeline code, agent reference
├── p1-scrna-atac/
│   ├── README.md
│   ├── data/               # Symlinks or download scripts (no raw data committed)
│   ├── notebooks/          # Quarto .qmd analysis notebooks
│   └── scripts/            # Standalone R/Python scripts
├── p2-sle-multiomics/
│   ├── README.md
│   ├── data/
│   ├── notebooks/
│   └── scripts/
│       └── cluster/        # SLURM sbatch and Nextflow configs
└── p3-dlbcl-spatial/
    ├── README.md
    ├── data/
    ├── notebooks/
    └── scripts/
```

## Key reference

SoRelle ED. *Epstein-Barr Virus Infection at Single-Cell Resolution.* J Med Virology 2026; 98:e70825. — Comprehensive field review with curated dataset Table 1 (all GEO/SRA accessions).

---

*Analysis performed on Mac M1 Max 64GB RAM (downstream) and HPC SLURM cluster (raw alignment). No wet lab components.*
