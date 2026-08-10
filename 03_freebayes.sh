#!/bin/bash
#SBATCH --job-name=freebayes
#SBATCH --array=1-69%15    # modern samples only — used for UME discovery
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=16:00:00
#SBATCH --output=logs/freebayes_%A_%a.out
#SBATCH --error=logs/freebayes_%A_%a.err

source config.sh
module load freebayes/1.3.10
module load BCFtools/1.24-GCC-14.3.0

OUTDIR=$OUTROOT/freebayes
mkdir -p $OUTDIR logs

# Discovery uses modern samples only; ancient samples run in UME production
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $MODERN_BAM_LIST)
SAMPLE=$(basename $BAM .bam)

echo "[$(date)] Starting FreeBayes for $SAMPLE"

# Notes:
#   --targets          : restrict to mappability-filtered BED (same as -t)
#   --min-base-quality : matches mapDamage-rescaled base quality threshold
#   --min-mapping-quality : matches upstream MAPQ≥20 filter
#   --ploidy 2         : diploid (default); ancient samples run as diploid here
#                        since UME handles the ensemble merging downstream
#   --no-partial-observations : skip complex multi-allelic sites
#   --use-best-n-alleles 4    : cap alt alleles considered (speeds things up)
#   FreeBayes is single-threaded; parallelism is via the SLURM array

freebayes \
    -f $REF \
    --targets $BED \
    --min-base-quality 20 \
    --min-mapping-quality 20 \
    --ploidy 2 \
    --no-partial-observations \
    --use-best-n-alleles 4 \
    $BAM \
| bgzip -c > $OUTDIR/${SAMPLE}.freebayes.vcf.gz

bcftools index -t $OUTDIR/${SAMPLE}.freebayes.vcf.gz

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.freebayes.vcf.gz"

# -------------------------------------------------------------------------
# FreeBayes can also be run on all 80 BAMs jointly (one output VCF):
#
#   freebayes -f $REF --targets $BED \
#       $(cat $BAM_LIST | sed 's/^/-b /') \
#   | bgzip -c > freebayes_all80.vcf.gz
#
# Per-sample mode above is slower overall but distributes across SLURM nodes.
# For UME discovery DB: per-sample VCFs are what's needed.
# -------------------------------------------------------------------------
