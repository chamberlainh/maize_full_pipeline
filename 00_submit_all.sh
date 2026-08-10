#!/bin/bash
# =============================================================================
# MASTER SUBMISSION SCRIPT
# Run this from your working directory to submit all 4 caller arrays.
# All 4 can run simultaneously — they are independent per-sample jobs.
#
# Before running:
#   1. Edit config.sh with your actual paths
#   2. Verify realigned_bams.txt has exactly 80 lines
#   3. Check Singularity is available (for DeepVariant)
#   4. mkdir -p logs
# =============================================================================

source config.sh

# Validate input
N=$(wc -l < $BAM_LIST)
echo "BAM list: $N samples found"
if [ "$N" -ne 80 ]; then
    echo "WARNING: expected 80 samples, found $N"
fi

# Check Singularity for DeepVariant
if ! command -v singularity &> /dev/null && ! command -v apptainer &> /dev/null; then
    echo ""
    echo "WARNING: neither singularity nor apptainer found in PATH."
    echo "Check with: module avail singularity apptainer"
    echo "DeepVariant script will fail until this is resolved."
    echo ""
fi

# Submit all 4 callers (independent — no dependencies between them)
echo "Submitting bcftools mpileup..."
JOB1=$(sbatch 01_bcftools_mpileup.sh | awk '{print $4}')
echo "  Job ID: $JOB1"

echo "Submitting GATK4 HaplotypeCaller..."
JOB2=$(sbatch 02_gatk_haplotypecaller.sh | awk '{print $4}')
echo "  Job ID: $JOB2"

echo "Submitting FreeBayes..."
JOB3=$(sbatch 03_freebayes.sh | awk '{print $4}')
echo "  Job ID: $JOB3"

echo "Submitting DeepVariant..."
JOB4=$(sbatch 04_deepvariant.sh | awk '{print $4}')
echo "  Job ID: $JOB4"

echo ""
echo "All jobs submitted. Monitor with:"
echo "  squeue -u \$USER"
echo "  sacct -j $JOB1,$JOB2,$JOB3,$JOB4 --format=JobID,State,Elapsed"
echo ""
echo "Expected outputs per sample:"
echo "  mpileup/    {sample}.ALL.mpileup.gz          (UME production input)"
echo "  gatkhc/     {sample}.g.vcf.gz                (GVCF for joint genotyping)"
echo "  freebayes/  {sample}.freebayes.vcf.gz"
echo "  deepvariant/{sample}.deepvariant.vcf.gz"
echo ""
echo "After all jobs finish, run the post-processing steps in:"
echo "  05_post_calling.sh"
