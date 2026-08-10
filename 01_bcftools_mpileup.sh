#!/bin/bash
#SBATCH --job-name=mpileup
#SBATCH --array=1-69%20    # modern samples only — used for UME discovery
#SBATCH --cpus-per-task=2
#SBATCH --mem=12G
#SBATCH --time=8:00:00
#SBATCH --output=logs/mpileup_%A_%a.out
#SBATCH --error=logs/mpileup_%A_%a.err

source config.sh
module load BCFtools/1.24-GCC-14.3.0

OUTDIR=$OUTROOT/mpileup
mkdir -p $OUTDIR logs

# Discovery uses modern samples only; ancient samples run in UME production
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $MODERN_BAM_LIST)
SAMPLE=$(basename $BAM .bam)

echo "[$(date)] Starting mpileup for $SAMPLE"

# bcftools mpileup outputs VCF format with AD and DP tags.
# UME production reads this format — it is NOT raw samtools pileup text.
bcftools mpileup \
    -f $REF \
    -R $BED \
    -a AD,DP \
    -Q 20 \
    -q 20 \
    --output-type z \
    --output $OUTDIR/${SAMPLE}.ALL.mpileup.gz \
    $BAM

bcftools index -t $OUTDIR/${SAMPLE}.ALL.mpileup.gz

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.ALL.mpileup.gz"

# -------------------------------------------------------------------------
# After all 80 jobs finish, generate the UME production input list:
#   ls $OUTDIR/*.ALL.mpileup.gz | xargs -n1 basename > in_prod_mpileup_files.lst
# -------------------------------------------------------------------------
