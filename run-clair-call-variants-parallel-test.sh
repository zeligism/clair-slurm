#!/bin/bash
#SBATCH --job-name=clair-call-variants
#SBATCH --output=clair-call-variants-%j.out
#SBATCH --error=clair-call-variants-%j.err
#SBATCH --time=0:30:00
#SBATCH --cpus-per-task=24
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aa5525@nyu.edu

module purge
source activate clair

CLAIR_DIR="/scratch/aa5525/clair"
VCF_DIR="$CLAIR_DIR/data/vcf"
CLAIR="$CLAIR_DIR/Clair/clair.py"

SAMPLE_NAME="HG001"
MODEL="$CLAIR_DIR/models/illumina/model"
BAM="$CLAIR_DIR/data/testingData/chr21/chr21.bam"
REF="$CLAIR_DIR/data/testingData/chr21/chr21.fa"

mkdir -p "$VCF_DIR"
OUTPUT_PREFIX="${VCF_DIR}/var"
VCF="$VCF_DIR/clair_snp_and_indel.${SAMPLE_NAME}.vcf.gz"
THRESHOLD=0.2  # min allele freq for considering a variant candidate site

# Number of parallel jobs to run
(( N_JOBS = 1 + $(nproc) / 2 ))
#N_JOBS=$(nproc)
echo "Running $N_JOBS jobs in parallel."

# Assuming contig is 40M bp long, call variants on chunks in parallel for each core
(( REGION_CHUNK_SIZE = 40000000 / $N_JOBS ))

# disable GPU if you have one installed
export CUDA_VISIBLE_DEVICES=""

# Create temporary file containing jobs to be executed in parallel
command_file=$(mktemp)
python $CLAIR callVarBamParallel \
       --sampleName "$SAMPLE_NAME" \
       --chkpnt_fn "$MODEL" \
       --bam_fn "$BAM" \
       --ref_fn "$REF" \
       --output_prefix "$OUTPUT_PREFIX" \
       --threshold $THRESHOLD \
       --refChunkSize $REGION_CHUNK_SIZE \
       --pysam_for_all_indel_bases \
       > $command_file

# Run jobs in parallel
cat $command_file | parallel -j $N_JOBS

# Find incomplete VCF files and rerun them
for i in ${OUTPUT_PREFIX}.*.vcf; do
  if ! [ -z "$(tail -c 1 "$i")" ]; then
    echo "$i"
  fi
done | grep -f - $command_file | sh

# concatenate vcf files and sort the variants called
vcfcat ${OUTPUT_PREFIX}.*.vcf | bcftools sort -m 2G | bgziptabix $VCF

# We don't need the command file anymore
rm $command_file
