#!/bin/bash
#SBATCH --job-name=deepvariant
#SBATCH --array=1-69%10    # modern samples only — used for UME discovery
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=logs/deepvariant_%A_%a.out
#SBATCH --error=logs/deepvariant_%A_%a.err
# Uncomment the line below if GPU nodes are available on LISC:
##SBATCH --gres=gpu:1

source config.sh

OUTDIR=$OUTROOT/deepvariant
DV_TMPDIR=$OUTDIR/tmp
mkdir -p $OUTDIR $DV_TMPDIR logs

# Discovery uses modern samples only; ancient samples run in UME production
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $MODERN_BAM_LIST)
SAMPLE=$(basename $BAM .bam)

echo "[$(date)] Starting DeepVariant for $SAMPLE"

# =============================================================================
# SETUP — run once BEFORE submitting the array (do this on the login node):
#
#   cd /lisc/data/scratch/pinhasilab/Pinhasi_group/Heather/
#   /usr/bin/singularity pull deepvariant_1.6.1.sif \
#     docker://google/deepvariant:1.6.1
#
#   This downloads ~5 GB and takes 10–20 min. Run it in a screen session
#   or submit as a short interactive job:
#     srun --mem=4G --time=1:00:00 --pty bash
# =============================================================================

# Path to the Singularity image
DV_SIF=/lisc/data/scratch/pinhasilab/Pinhasi_group/Heather/deepvariant_1.6.1.sif

# Directories that need to be visible inside the container
REF_DIR=$(dirname $REF)
BAM_DIR=$(dirname $BAM)
BED_DIR=$(dirname $BED)

# Run DeepVariant via Singularity
# --bind mounts host paths into the container at the same location
/usr/bin/singularity exec \
    --bind $REF_DIR,$BAM_DIR,$BED_DIR,$OUTDIR,$DV_TMPDIR \
    $DV_SIF \
    run_deepvariant \
        --model_type WGS \
        --ref $REF \
        --reads $BAM \
        --regions $BED \
        --output_vcf $OUTDIR/${SAMPLE}.deepvariant.vcf.gz \
        --output_gvcf $OUTDIR/${SAMPLE}.deepvariant.g.vcf.gz \
        --sample_name $SAMPLE \
        --num_shards $SLURM_CPUS_PER_TASK \
        --intermediate_results_dir $DV_TMPDIR/${SAMPLE}

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.deepvariant.vcf.gz"

# -------------------------------------------------------------------------
# Notes on model choice:
#   --model_type WGS    : short-read Illumina WGS model (best available for
#                         aDNA). DeepVariant has no aDNA-specific model.
#                         Damage is handled upstream by mapDamage rescaling,
#                         so this is acceptable.
#
# Notes on GPU:
#   Uncomment the #SBATCH --gres=gpu:1 line if GPU nodes are available.
#   DeepVariant runs ~3-5x faster on GPU during call_variants step.
#   The container includes GPU support automatically when a GPU is present.
#
# Notes on Apptainer (newer name for Singularity):
#   Replace 'singularity exec' with 'apptainer exec' if your LISC uses
#   Apptainer. The flags are identical.
# -------------------------------------------------------------------------
