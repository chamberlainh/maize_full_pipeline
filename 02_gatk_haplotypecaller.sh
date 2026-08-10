#!/bin/bash
#SBATCH --job-name=gatkhc
#SBATCH --array=1-69%15    # modern samples only — used for UME discovery
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=12:00:00
#SBATCH --output=logs/gatkhc_%A_%a.out
#SBATCH --error=logs/gatkhc_%A_%a.err

source config.sh
module load GATK/4.6.2.0-GCCcore-13.2.0-Java-17

OUTDIR=$OUTROOT/gatkhc
mkdir -p $OUTDIR logs

# Discovery uses modern samples only; ancient samples run in UME production
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $MODERN_BAM_LIST)
SAMPLE=$(basename $BAM .bam)

echo "[$(date)] Starting GATK4 HaplotypeCaller for $SAMPLE"

# Notes:
#   -ERC GVCF          : emit per-sample GVCF for later joint genotyping
#   -L $BED            : restrict to mappability-filtered sites
#   --tmp-dir          : GATK4 writes large temp files; set to scratch if needed
#   --native-pair-hmm-threads : parallel pair HMM (match --cpus-per-task above)
#   Ancient samples: GATK HC is designed for diploid; aDNA damage is handled
#   upstream by mapDamage rescaling, so no extra flags needed here.

gatk HaplotypeCaller \
    -R $REF \
    -I $BAM \
    -O $OUTDIR/${SAMPLE}.g.vcf.gz \
    -L $BED \
    -ERC GVCF \
    --min-base-quality-score 20 \
    --native-pair-hmm-threads 4 \
    --tmp-dir $TMPDIR \
    --sample-name $SAMPLE

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.g.vcf.gz"

# -------------------------------------------------------------------------
# After all 80 GVCFs are generated, combine and genotype jointly:
#
#   # Step 1: Combine GVCFs
# For 80 samples, use GenomicsDBImport (more scalable than CombineGVCFs):
#
#   # Build sample map: samplename\t/path/to/sample.g.vcf.gz
#   for F in $OUTDIR/*.g.vcf.gz; do
#     S=$(basename $F .g.vcf.gz)
#     echo -e "$S\t$F"
#   done > sample_map.txt
#
#   # GenomicsDBImport per chromosome (submit as separate job, ~64G RAM)
#   for CHR in $CHROMS; do
#     gatk GenomicsDBImport \
#       --sample-name-map sample_map.txt \
#       -L $CHR \
#       --genomicsdb-workspace-path genomicsdb_${CHR} \
#       --reader-threads 4
#   done
#
#   # GenotypeGVCFs per chromosome
#   for CHR in $CHROMS; do
#     gatk GenotypeGVCFs \
#       -R $REF \
#       -V gendb://genomicsdb_${CHR} \
#       -L $BED \
#       -O $OUTDIR/gatkhc_joint_${CHR}.vcf.gz
#   done
#
#   # Merge into one VCF
#   module load BCFtools/1.24-GCC-14.3.0
#   bcftools concat -Oz \
#     $(for CHR in $CHROMS; do echo $OUTDIR/gatkhc_joint_${CHR}.vcf.gz; done) \
#     -o $OUTDIR/gatkhc_joint_all.vcf.gz
#   bcftools index -t $OUTDIR/gatkhc_joint_all.vcf.gz
# -------------------------------------------------------------------------
