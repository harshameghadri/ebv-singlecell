# P3 — Spatial: EBV+ DLBCL Tumour Microenvironment

Spatial transcriptomics re-analysis of EBV+ vs EBV− DLBCL, combining two complementary datasets and supplemented by TCGA-DLBC computational pathology.

## Science

EBV conditions an immunosuppressive TME in DLBCL via LMP1-driven macrophage skewing and T cell exclusion. Prior papers (He et al. 2025, IN-DEPTH 2024) describe the TME composition but do not resolve EBV latency programmes spatially, perform neighbourhood enrichment analysis, or connect morphological niches to transcriptomic cell states. This project addresses all three gaps.

**Note:** He et al. *Sci. Rep.* 2025 (PMC12058988) Visium data is **not publicly deposited** (confirmed). GSE274051 is the primary substitute.

## Data

| Dataset | Accession | Notes |
|---|---|---|
| HIV-NHL Visium (primary) | GEO: GSE274051 | 10 samples, 5 EBV+, Visium V2, open access |
| IN-DEPTH spatial multi-omics | Zenodo: 14639480 + 18379156 | VisiumHD + GeoMx + CODEX, EBV+/− DLBCL |
| TCGA-DLBC RNA-seq counts | GDC open access | 48 cases, EBV+ identified computationally |
| TCGA-DLBC WSI slides | GDC open access | FFPE DX slides, ~60-80 GB |

```bash
# GSE274051 — primary Visium dataset
wget -c https://ftp.ncbi.nlm.nih.gov/geo/series/GSE274nnn/GSE274051/suppl/GSE274051_RAW.tar

# Zenodo IN-DEPTH data
for RECORD in 14639480 18379156; do
  curl -s https://zenodo.org/api/records/${RECORD} \
    | python3 -c "
import sys, json
record = json.load(sys.stdin)
for f in record['files']:
    import subprocess
    subprocess.run(['wget', '-c', '-O', f['key'], f['links']['self']])
"
done

# TCGA-DLBC counts (R)
# library(TCGAbiolinks)
# query <- GDCquery(project="TCGA-DLBC", data.category="Transcriptome Profiling",
#                   data.type="Gene Expression Quantification", workflow.type="STAR - Counts")
# GDCdownload(query)
```

## Analysis plan

### Layer 1: Visium spatial re-analysis (GSE274051)
- [ ] Load Visium samples, SCTransform normalisation, spatially variable features
- [ ] RCTD deconvolution using matched DLBCL scRNA-seq reference
- [ ] Reproduce immunosuppressive TME signatures (EBV+ vs EBV−)
- [ ] **EBV latency scoring per spot** — LMP1/EBNA2 downstream host signatures (Latency I/II/III proxy)
- [ ] **Neighbourhood enrichment** — frNN radius graph + permutation test (CD163⁺ macrophages near EBV+ tumour spots?)
- [ ] **Spatially-resolved cell-cell communication** — CellChat with proximity weights
- [ ] TLR4 spatial pattern by cell type and tissue region

### Layer 2: IN-DEPTH multi-omics (Zenodo)
- [ ] Integrate GeoMx + VisiumHD + CODEX data per sample
- [ ] Reproduce tumour-macrophage-CD4 T cell immunosuppressive axis (EBV+)
- [ ] Spatial gradient analysis relative to EBV+ tumour cell annotations

### Layer 3: TCGA-DLBC computational pathology
- [ ] EBV+ case identification from RNA-seq (unmapped reads → EBV genome; RPM threshold)
- [ ] Download FFPE DX WSI slides via gdc-client
- [ ] CONCH/UNI foundation model patch embeddings (PyTorch MPS, M1 GPU)
- [ ] Morphological niche discovery: UMAP → Leiden clustering on embeddings
- [ ] Compare niche proportions EBV+ vs EBV− cases
- [ ] Survival analysis: Cox PH on niche enrichment scores vs OS/PFS (TCGAbiolinks clinical)
- [ ] Qualitative bridge: match morphological niches to Visium cell type signatures

## Output
If latency scoring + neighbourhood enrichment yield EBV-specific spatial patterns → short bioRxiv data analysis paper: *"EBV latency programme shapes immunosuppressive spatial niches in DLBCL."*

## Stack
Seurat spatial, Squidpy, RCTD, SPOTlight, CellChat, LIANA, dbscan, TIAToolbox, CONCH/UNI (HuggingFace), PyTorch MPS, QuPath, TCGAbiolinks, survival (R), ComplexHeatmap
