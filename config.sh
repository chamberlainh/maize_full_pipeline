#!/bin/bash
# =============================================================================
# SHARED CONFIG — source this at the top of every caller script
# Edit paths here once; all scripts inherit them.
# =============================================================================

# Reference genome (B73 NAM-5.0)
REF=/path/to/Zm-B73-REFERENCE-NAM-5.0.fa

# Mappability-filtered site list (Kistler lab, k=35, ~10% genome)
BED=/path/to/SNP_calling_sitesV5.bed

# All 80 realigned BAMs (ancient + modern) — used for UME production
BAM_LIST=/path/to/realigned_bams.txt

# Modern samples only (69) — used for UME discovery dictionary
# Ancient samples are NOT included in discovery; they are genotyped in production
# against the dictionary built from modern samples.
MODERN_BAM_LIST=/path/to/modern_bams.txt

# Root output directory for all callers
OUTROOT=/path/to/variant_calling

# GATK4 jar (or 'gatk' if on PATH / module loaded)
GATK4=gatk    # replace with full path if needed

# NAM-5.0 chromosomes (for per-chromosome parallelism)
CHROMS="NC_050096.1 NC_050097.1 NC_050098.1 NC_050099.1 NC_050100.1 \
        NC_050101.1 NC_050102.1 NC_050103.1 NC_050104.1 NC_050105.1"
