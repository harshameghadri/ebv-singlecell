EBV Single-Cell Processing Pipeline: Scripts Usage Guide

This document contains explicit instructions for using the bash scripts developed for the GEX, BCR, and CIT data processing pipeline.

IMPORTANT NOTE: These pipelines run for hours or days. You should always execute them inside a multiplexer like tmux.

Quick start: bash launch_tmux.sh to initialize the pre-configured workflow session.

0. Pipeline Orchestration

Script: launch_tmux.sh

What it does:

Creates a named tmux session (ebv_pipeline) with three parallel windows:

Window 0 (refs): Sequentially runs reference downloads and STAR index building.

Window 1 (fastq): Runs the FASTQ download script.

Window 2 (monitor): Runs a watch command updating every 60s to show disk usage, tail the download logs, and monitor active fasterq-dump or STAR processes.

Usage:

# Start the session and attach to it
bash launch_tmux.sh

# Reattach later if your SSH connection drops
tmux attach -t ebv_pipeline


1. References & Indexing

Scripts: 01_download_references.sh and 02_build_star_index.sh

What they do:

01_download_references.sh: Downloads GRCh38 (Ensembl 110) and EBV (NC_007605.1). It converts the EBV GFF3 to GTF, and concatenates the human and viral genomes into composite .fa and .gtf files.

02_build_star_index.sh: Builds the STAR index from the composite genome using 32 threads. It specifies --sjdbOverhang 149 (optimized for 150bp paired-end reads).

Usage:

These run automatically if you use launch_tmux.sh, but to run manually:

bash 01_download_references.sh
bash 02_build_star_index.sh


2. FASTQ Downloading (Two Options)

Option A: ENA Downloader (Highly Recommended)

Script: 03_download_fastq_ena.sh

What it does:

The fastest and most disk-efficient method. Queries the European Nucleotide Archive (ENA) API for pre-compressed .fastq.gz files and downloads them directly using wget -c (which allows instant resuming).

Zero Extraction Overhead: Bypasses fasterq-dump completely for synced files.

Smart Fallback: If a sample (e.g., SRR35978533) is not on ENA, it gracefully falls back to the NCBI SRA fasterq-dump + pigz method.

Retroactive Safety: Scans for existing >100MB FASTQs and retroactively marks them complete to prevent redownloading.

Options:

--max_download N : Set the maximum number of parallel downloads (Default: 2).

--skip SAMPLES : Comma-separated list of Donors or SRR IDs to skip entirely.

[gex|bcr|cit] : Specify which manifest(s) to process. If none provided, runs all three.

Examples:

# Default run: all library types, 2 at a time
bash 03_download_fastq_ena.sh

# Download only GEX samples, up to 5 at a time, skipping completed ones
bash 03_download_fastq_ena.sh --max_download 5 --skip HC2,HC4,HC6,HC7,HC8c gex


Option B: Pure NCBI SRA Downloader (Legacy)

Script: 03_download_fastq.sh (or 03_download_fastq_parallel.sh)

What it does:

The traditional toolkit approach. Uses fasterq-dump with a 10GB RAM buffer (--mem 10G) to minimize random network writes. It then utilizes pigz to compress R1 and R2 simultaneously to save time, followed by aggressive cache deletion. Uses the exact same CLI flags as the ENA script.

3. Cell Ranger & TRUST4 Pipeline

Script: 04_Run_GEX_cellranger.sh

What it does:

Performs sequential, end-to-end processing of single-cell GEX data. Designed to aggressively manage disk space on the HPC by processing one sample at a time.

Pre-processing: Automatically renames SRA-style FASTQs (_1.fastq.gz) into the strict 10x Genomics format required by Cell Ranger.

Cell Ranger: Runs cellranger count to generate the expression matrix and BAM file.

FASTQ Cleanup: Instantly deletes the raw FASTQ files to reclaim 50GB-100GB of disk space.

TRUST4: Runs run-trust4 on the Cell Ranger BAM to extract immune repertoires.

BAM Cleanup: Deletes the massive .bam and .bai files immediately after TRUST4 finishes.

Options:

--samples SAMPLES : Only process specific samples (comma-separated list).

--continue-trust4 : Skip Cell Ranger. Search for existing BAM files and run TRUST4 on them.

--skip-trust4 : Run Cell Ranger only. Preserve the BAM files and exit.

--trust4-only SAMPLE : Run TRUST4 on one specific sample's BAM file, delete the BAM, and exit.

--dry-run : Print out the commands that would run without actually executing them.

Examples:

# Run the full end-to-end pipeline on all available samples in the manifest
bash 04_Run_GEX_cellranger.sh

# Test syntax without running compute tools:
bash 04_Run_GEX_cellranger.sh --samples SLE1,SLE2b --dry-run

# Run the full pipeline ONLY on HC1 and HC2
bash 04_Run_GEX_cellranger.sh --samples HC1,HC2

# If Cell Ranger finished but TRUST4 failed/skipped, resume TRUST4 for all:
bash 04_Run_GEX_cellranger.sh --continue-trust4
