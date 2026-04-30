# EBV Single-Cell & Spatial Portfolio — PROJECT.md
**Master chain-of-thought, progress, and idea tracking file**
Last updated: 2026-04-30

---

## MISSION STATEMENT

**Main Goal:** Data analysis portfolio demonstrating computational multi-omic expertise across EBV biology  
**Stretch Goal:** Novel integrated insights into EBV pathogenesis — standalone bioRxiv/journal paper  
**Constraint:** Purely computational. No wet lab. No funding. No novel experiments.  
**Hardware:** Mac M1 Max 64GB RAM (local downstream analysis) + HPC cluster with SLURM (1 month, raw data processing only)

---

## UNIFYING SCIENTIFIC NARRATIVE

The portfolio is held together by a single biological thread:

> **EBV hijacks a conserved TBX21+CXCR3+ atypical B cell (ABC) programme across primary infection, autoimmunity, and malignancy.**

This manifests as:
- **P1** — EBV drives GC-independent chromatin opening at ABC loci in primary B cell infection (scATAC-seq)
- **P2** — EBV reprograms autoreactive SLE B cells via EBNA2 into APC-competent ABCs (multi-omic)
- **P3** — EBV conditions immunosuppressive spatial niches in DLBCL TME via LMP1-driven macrophage skewing (spatial)
- **Cross-cutting** — TBX21+FCRL4+ B cells appear in NPC TME; EBV+ ABCs migrate to CNS in humanized mice (GSE299939, *Nature* 2025)

If the stretch goal is pursued, the paper frames EBV as a unified driver of the ABC programme across disease contexts — testable computationally by scoring the ABC signature across all datasets.

---

## PROJECT OVERVIEW

### P1 — scATAC-seq Replication: EBV Chromatin Landscapes
| Field | Detail |
|---|---|
| Source paper | SoRelle et al., *Cell Reports* 2023, DOI:10.1016/j.celrep.2023.112958 |
| Companion RNA paper | SoRelle et al., *Cell Reports* 2022 (time-resolved scRNA-seq, same experiment) |
| PI | Elliott D. SoRelle (now at U Michigan, scEBV Lab) |
| Data | GEO: GSE189141 — processed MTX/TSV/BIGWIG (71.2 GB tar) |
| Code | Zenodo: https://zenodo.org/records/8125208 |
| Status | **DOWNLOADING** — GSE189141_RAW.tar via FTP |
| Analysis platform | Local M1 Max — no cluster needed |

**Science:** EBV+ B cells split into arrested (antiviral/chromatin closure) vs. proliferative (GC-like accessibility without BCL6). Key finding: EBV elicits DZ/LZ chromatin architecture despite BCL6 downregulation. T-bet+CXCR3+ B cell niche identified as ABC-like.

**Novel extensions we will add:**
1. Map ATAC reads to EBV genome (NC_007605.1) per cell state — not done in original
2. ArchR peak2gene linkage at BCL2/MCL1/BCL2A1 anti-apoptotic loci (links to companion mBio BCL2A1 paper)
3. Pseudotime of chromatin opening events (kinetics of GC programme engagement)
4. EBNA2 ChIP peak overlap quantification per DAP per cell state

**Stack:** R, Signac, ArchR, chromVAR, MACS2, BSgenome.Hsapiens, Seurat WNN, Quarto

---

### P2 — EBV Multi-Omic Re-Analysis: SLE Autoreactive B Cells
| Field | Detail |
|---|---|
| Source paper | Younis et al., *Sci. Transl. Med.* 2025, DOI:10.1126/scitranslmed.ady0210 |
| Data | SRA BioProject: PRJNA1301449 (raw SRA — multiple assay types) |
| Status | **CLUSTER RUNNING** — SRA download in progress, check completion |
| Key methodological requirement | Composite human+EBV reference (GRCh38 + NC_007605.1) for all alignment |

**Assay types expected in PRJNA1301449:**
- scRNA-seq (10x 5' — allows VDJ recovery)
- ChIP-seq: EBNA2 occupancy
- ChIP-seq: RNA Pol II occupancy
- ATAC-seq: bulk, EBV+ vs EBV- B cells
- Possibly BCR VDJ (embedded in 5' scRNA or separate)

**Science:** EBNA2 directly binds and activates CD27, ZEB2, TBX21 loci, converting SLE autoreactive B cells into APC-competent ABCs. Paper used novel EBV detection strategy via composite genome alignment.

**Novel extensions we will add:**
1. **Pol II pausing index** at EBNA2 target genes (TSS-proximal vs gene-body density) — not reported in paper
2. **EBV latency programme scoring** per cell (Latency I/II/III by EBNA/LMP transcript profile) — not resolved
3. **BCR clonotype overlap** between EBV+ and ANA-reactive clones (scRepertoire + TRUST4)
4. **TCR side** — if T cells captured, are there restricted clonotypes in T cells activated by EBV-reprogrammed APCs?

**Tool swaps for M1 Mac compatibility:**
- Cell Ranger → STARsolo (ARM64 native via conda-forge)
- VDJ assembly → TRUST4 (runs from BAM, no Cell Ranger VDJ needed)

**Stack:** STARsolo, TRUST4, Bowtie2, MACS3, HOMER, deepTools, DiffBind, Seurat, Signac, scRepertoire, SLURM

---

### P3 — EBV+ DLBCL Spatial TME: Re-Analysis + Computational Pathology
| Field | Detail |
|---|---|
| Original target | He et al., *Sci. Rep.* 2025, PMC12058988 |
| Data availability | **NOT PUBLICLY AVAILABLE** — Chinese hospital data, no GEO accession. Confirmed via SoRelle 2026 review Ref[78]. Email authors as low-priority action. |
| **PRIMARY SUBSTITUTE** | Chadburn et al., HIV-NHL Visium, GEO: **GSE274051** — 10 samples, 5 EBV+, Visium V2, publicly available |
| Secondary spatial | IN-DEPTH paper (PMC11702642, Yeo et al.) — VisiumHD + GeoMx + CODEX, EBV+/- DLBCL, Zenodo: 14639480 + 18379156 |
| TCGA layer | TCGA-DLBC: 48 cases, RNA-seq counts (open access), WSI slides via GDC |
| Status | **QUEUED** — Zenodo 14639480 + 18379156 downloading |

**Science (He et al. gaps we will address using substitute data):**
1. No neighbourhood enrichment analysis done → apply frNN/permutation approach
2. EBV latency programme never scored spatially → Latency I/II/III per spot
3. TLR4 spatial pattern not shown despite being flagged as key finding
4. GCB vs ABC DLBCL subtype not resolved spatially
5. Reference for deconvolution is unmatched published data — consider LDA-based approach

**Computational pathology angle (TCGA-DLBC):**
- EBV+ case identification from RNA-seq: align unmapped reads to EBV genome, threshold by EBER1/RPMS1 signal
- Download DX FFPE WSI slides via gdc-client (~60-80 GB)
- CONCH or UNI foundation model patch embeddings (PyTorch MPS on M1 GPU — runs inference only)
- Morphological niche discovery: UMAP → Leiden clustering on patch embeddings
- Compare niche proportions EBV+ vs EBV- cases
- Bridge qualitatively to Visium niches from GSE274051

**Stack:** Seurat spatial, Squidpy, RCTD/SPOTlight, CellChat, LIANA, dbscan, TIAToolbox, CONCH/UNI (HuggingFace), PyTorch MPS, QuPath, TCGAbiolinks, survival (R)

---

## ADDITIONAL DATASETS IDENTIFIED (from SoRelle 2026 JMV review, Table 1)

All have GEO/SRA accessions and are publicly available:

| Dataset | Accession | Relevance |
|---|---|---|
| LCL transcriptomic continuum + T-bet+ B cells | GSE158275 | Baseline ABC characterisation; links P1→P2 |
| MS/CIS CITE-seq ABCs (SoRelle 2025 JCI Insight) | GSE267750 | Cross-disease ABC scoring; links P2→autoimmunity |
| EBV CNS homing humanized mouse (Nature 2025) | GSE299939 + Zenodo | In vivo ABC migration; mechanistic ABC narrative anchor |
| NPC scRNA-seq (14 samples, scVDJ, TME) | GSE150825 | Latency scoring validation dataset; TBX21+FCRL4+ B cells |
| NPC scRNA-seq (10 blood-matched pairs) | GSE162025 | Paired tumour/PBMC; exhausted CD8 clonality |
| NPC scRNA-seq (15 samples) | GSE150430 | Largest NPC dataset; immune response signatures |
| CAEBV PBMCs | GSE231946 | EBV across HSCs; extreme latency heterogeneity |
| MIS-C TGFb-EBV reactivation | GSE254179 | TGFb-EBV reactivation axis; unexpected disease connection |
| HIV-NHL Visium (P3 primary substitute) | GSE274051 | **10 samples, 5 EBV+, Visium V2** |
| IM tonsil spatial (Phenocycler+CosMx) | bioRxiv 2025 — upon publication | Spatial latency I/II/III resolved in primary infection |

**Priority downloads (small, processed matrices, local Mac):**
1. GSE274051 — start now, P3 anchor dataset
2. GSE158275 — LCL baseline
3. GSE267750 — MS/CIS ABCs
4. GSE150825 — NPC latency scoring validation

---

## KEY REFERENCE

**SoRelle ED. "Epstein-Barr Virus Infection at Single-Cell Resolution." *J Med Virology* 2026; 98:e70825. DOI:10.1002/jmv.70825**

This is a comprehensive field-level review by the P1 paper's PI. Table 1 is a curated master list of every EBV single-cell and spatial dataset with accession numbers. This review should be re-read before each project phase to orient decisions. Open access.

---

## DOWNLOAD STATUS TRACKER

| Dataset | Type | Location | Status |
|---|---|---|---|
| PRJNA1301449 (Younis) | Raw SRA — multiple assays | Cluster | Running — check completion |
| GSE189141_RAW.tar | Processed matrices | Mac/cluster | Downloading via FTP |
| Zenodo 14639480 | IN-DEPTH spatial data | Mac | Downloading (API method) |
| Zenodo 18379156 | IN-DEPTH spatial data | Mac | Downloading (API method) |
| GSE274051 | HIV-NHL Visium (P3) | Mac | QUEUED — start next |
| TCGA-DLBC RNA-seq | Count matrices | Mac | QUEUED — TCGAbiolinks pull |
| TCGA-DLBC WSI slides | FFPE DX images | External SSD | QUEUED — gdc-client |
| GSE158275 | LCL scRNA-seq | Mac | QUEUED |
| GSE267750 | MS/CIS CITE-seq | Mac | QUEUED |
| GSE150825 | NPC scRNA-seq | Mac | QUEUED |

---

## IDEAS PARKING LOT (tangents to revisit only after core analysis complete)

- NPC abortive lytic cycle → monocyte recruitment spatial validation (PLoS Pathogens 2024)
- CAEBV infection across HSCs — could add a "latency across lineages" angle to P2
- MIS-C TGFb-EBV axis (GSE254179) — unexpected EBV connection, low priority
- Cross-disease ABC meta-analysis (SLE + MS + IM + HIV-NHL) — stretch goal only
- Infectious mononucleosis tonsil spatial (Leahy bioRxiv 2025) — data not yet public, monitor

---

## GUARDRAILS (to prevent productive tangents becoming distractions)

1. **Finish before expanding.** No new dataset downloads until P1 analysis is producing figures.
2. **ABC narrative first.** Every analysis should ask: does this illuminate the ABC/TBX21 thread?
3. **No wet lab framing.** All language must describe what is computationally testable from public data.
4. **Portfolio artifacts are non-negotiable.** Every project ends with a Quarto report on GitHub Pages.
5. **Stretch paper only if P1+P2+P3 yield a coherent cross-disease finding.** Don't write before the data speaks.
