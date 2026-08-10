#!/bin/bash
# =============================================================================
# POST-CALLING — run after all 4 caller arrays complete
# Generates the file lists UME needs and does the GATK joint genotyping step.
# =============================================================================

source config.sh
module load GATK/4.6.2.0-GCCcore-13.2.0-Java-17
module load BCFtools/1.24-GCC-14.3.0

OUTDIR=$OUTROOT

# -----------------------------------------------------------------------------
# 1. Generate UME production input list (bcftools mpileup files)
# -----------------------------------------------------------------------------
echo "Generating UME production input list..."
ls $OUTDIR/mpileup/*.ALL.mpileup.gz | xargs -n1 basename > in_prod_mpileup_files.lst
echo "  $(wc -l < in_prod_mpileup_files.lst) files listed in in_prod_mpileup_files.lst"

# -----------------------------------------------------------------------------
# 2. GATK joint genotyping (80 samples via GenomicsDBImport)
# Run as a standalone job — this step needs ~64 GB RAM for 80 samples
# -----------------------------------------------------------------------------
# Submit as a separate job:
# sbatch --mem=64G --cpus-per-task=8 --time=24:00:00 --wrap="bash 05_gatk_joint.sh"

echo ""
echo "GATK joint genotyping is resource-intensive (64 GB, 8 CPUs recommended)."
echo "Submit it as a separate job rather than running inline."
echo "See the commented block below for the commands."

# Commands for reference (paste into a dedicated job script):
#
# # GenomicsDBImport (per-chromosome for scalability)
# for CHR in $CHROMS; do
#   gatk GenomicsDBImport \
#     $(ls $OUTDIR/gatkhc/*.g.vcf.gz | sed 's/^/-V /') \
#     -L $CHR \
#     --genomicsdb-workspace-path genomicsdb_${CHR} \
#     --reader-threads 4
# done
#
# # GenotypeGVCFs (per chromosome, then merge)
# for CHR in $CHROMS; do
#   gatk GenotypeGVCFs \
#     -R $REF \
#     -V gendb://genomicsdb_${CHR} \
#     -L $BED \
#     -O $OUTDIR/gatkhc/gatkhc_joint_${CHR}.vcf.gz
# done
#
# # Merge chromosomes into one VCF
# bcftools concat -Oz \
#   $(for CHR in $CHROMS; do echo $OUTDIR/gatkhc/gatkhc_joint_${CHR}.vcf.gz; done) \
#   -o $OUTDIR/gatkhc/gatkhc_joint_all.vcf.gz
# bcftools index -t $OUTDIR/gatkhc/gatkhc_joint_all.vcf.gz

# -----------------------------------------------------------------------------
# 3. Verify completeness — check all 80 samples produced output for each caller
# -----------------------------------------------------------------------------
echo ""
echo "Checking output file counts..."
echo "  mpileup:     $(ls $OUTDIR/mpileup/*.ALL.mpileup.gz 2>/dev/null | wc -l) / 80"
echo "  gatkhc:      $(ls $OUTDIR/gatkhc/*.g.vcf.gz 2>/dev/null | wc -l) / 80"
echo "  freebayes:   $(ls $OUTDIR/freebayes/*.freebayes.vcf.gz 2>/dev/null | wc -l) / 80"
echo "  deepvariant: $(ls $OUTDIR/deepvariant/*.deepvariant.vcf.gz 2>/dev/null | wc -l) / 80"

# Find any failed samples (SLURM jobs with non-zero exit codes will have 0-byte outputs)
echo ""
echo "Checking for empty/missing outputs in mpileup (failed jobs)..."
for F in $OUTDIR/mpileup/*.ALL.mpileup.gz; do
    SIZE=$(stat -c%s "$F" 2>/dev/null || echo 0)
    if [ "$SIZE" -lt 1000 ]; then
        echo "  WARNING: possibly empty — $F"
    fi
done

echo ""
echo "Next step:"
echo "  1. Contact Vallebueno for All.tlone.Merge.db.gz build scripts (Path B discovery)"
echo "     OR request existing discovery.ll for B73v5 (Path A production)"
echo "  2. Generate reference.fa.OL (see UME_preparation_guide.md Step 3)"
echo "  3. Run UME production: ume production -f in_prod_mpileup_files.lst ..."
