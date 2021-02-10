#!/bin/bash
#SBATCH --job-name=clair-training
#SBATCH --output=clair-training-%j.out
#SBATCH --error=clair-training-%j.err
#SBATCH --time=0:30:00
#SBATCH --cpus-per-task=24
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aa5525@nyu.edu

GOOGLE_TESTDATA_DIR="/scratch/aa5525/deepvariant-other/google/deepvariant/deepvariant/testdata"

# Set the steps that you want to test to "true".
# The steps set to "true" must be consecutive,
# and results from the previous steps should be available.
# If starting a fresh run, it's recommended to set CLEAR_DATA to "true".
CLEAR_DATA=false
PREPROCESS=false
STEP2=false
STEP3=false
STEP4=false
STEP5=false
STEP6=false
STEP7=false
STEP8=false
STEP9=false
STEP10=false
TRAIN=false

module purge
source activate clair

CLAIR_DIR="/scratch/aa5525/clair"
CLAIR="$CLAIR_DIR/Clair/clair.py"
PYPY=$(which pypy3)

# Model to be trained
MODEL="$CLAIR_DIR/models/illumina/model"
# Sample name
SAMPLE_NAME="NA12878"
# Reference genome
REF="$GOOGLE_TESTDATA_DIR/ucsc.hg19.chr20.unittest.fasta.gz"
# VCF file containing true variants
#TRUTH_VCF="$GOOGLE_TESTDATA_DIR/golden.vcf_caller_postprocess_single_site_output.vcf"
TRUTH_VCF="$GOOGLE_TESTDATA_DIR/test_nist.b37_chr20_100kbp_at_10mb.vcf.gz"
# please make sure the provided bam file is sorted and samtools indexed (e.g. hg001.bam)
BAM="$GOOGLE_TESTDATA_DIR/NA12878_S1.chr20.10_10p1mb.bam"
# dataset output folder (the directory will be created later)
DATASET_DIR="$CLAIR_DIR/data/training/${SAMPLE_NAME}.dataset"
# where to find the BAMs prefixed as the elements in the DEPTHS array (e.g. 1.000.bam 0.800.bam)
SUBSAMPLED_BAMS_DIR="$CLAIR_DIR/data/training/${SAMPLE_NAME}.subsampled_bams"
# chromosome prefix ("chr" if chromosome names have the "chr"-prefix)
CHR_PREFIX="chr"
# array of chromosomes (do not include "chr"-prefix)
CHR=(20)
# set to the number of CPU cores you have
THREADS=$(nproc)
# for multiple memory intensive steps, this number of cores will be used
(( THREADS_LOW = 1 + $THREADS / 2 ))

#################### PREPROCESSING ####################
if [ "$PREPROCESS" == true ]; then
  echo "Subsampling BAMs..."
  mkdir "$SUBSAMPLED_BAMS_DIR"
  if [ $? == 0 ]; then
    # FRAC values for 'samtools view -s INT.FRAC'
    # please refer to samtools' documentation for further information
    # in the exampled we set 80%, 40%, 20% and 10% of the full coverage
    DEPTHS=(800 400 200 100)
    # downsampling
    for i in "${!DEPTHS[@]}"; do
      samtools view -@ ${THREADS} -s ${i}.${DEPTHS[i]} -b ${BAM} \
      > ${SUBSAMPLED_BAMS_DIR}/0.${DEPTHS[i]}.bam
      samtools index -@ ${THREADS} ${SUBSAMPLED_BAMS_DIR}/0.${DEPTHS[i]}.bam
    done
    # add symbolic links for the orginal (full coverage) BAM
    ln -s ${BAM} ${SUBSAMPLED_BAMS_DIR}/1.000.bam
    ln -s ${BAM}.bai ${SUBSAMPLED_BAMS_DIR}/1.000.bam.bai
  else
    echo "Subsampled BAMs directory already exists. Skipping this step."
  fi
fi

#################### 1. Setup variables for building bin ####################
# array of coverages, (1.000) if downsampling was not used
DEPTHS=(1.000 0.800)
DEPTHS_PER_SAMPLE=${#DEPTHS[@]}
ESTIMATED_SPLIT_NO_OF_LINES=$((180000 * $DEPTHS_PER_SAMPLE))
MINIMUM_COVERAGE=4

VARIANT_DIR="${DATASET_DIR}/var"
CANDIDATE_DIR="${DATASET_DIR}/can"
TENSOR_VARIANT_DIR="${DATASET_DIR}/tensor_var"
TENSOR_CANDIDATE_DIR="${DATASET_DIR}/tensor_can"
TENSOR_PAIR_DIR="${DATASET_DIR}/tensor_pair"
SHUFFLED_TENSORS_DIR="${DATASET_DIR}/all_shuffled_tensors"
BINS_DIR="${DATASET_DIR}/all_bins"

#################### 2. Create directories ####################
if [ "$STEP2" == true ]; then
  if [ "$CLEAR_DATA" == true ]; then
    echo "Clearing old data..."
    rm -rf "$DATASET_DIR"
  fi
  mkdir -p "$DATASET_DIR"
  mkdir -p "$VARIANT_DIR"
  mkdir -p "$CANDIDATE_DIR"
  mkdir -p "$TENSOR_VARIANT_DIR"
  mkdir -p "$TENSOR_CANDIDATE_DIR"
  mkdir -p "$TENSOR_PAIR_DIR"
  mkdir -p "$SHUFFLED_TENSORS_DIR"
  mkdir -p "$BINS_DIR"

  # create directories for different coverages
  for j in "${!DEPTHS[@]}"; do
    mkdir -p "$TENSOR_VARIANT_DIR/${DEPTHS[j]}"
    mkdir -p "${TENSOR_CANDIDATE_DIR}/${DEPTHS[j]}"
    mkdir -p "${TENSOR_PAIR_DIR}/${DEPTHS[j]}"
  done

  echo "Created a new dataset directory: ${DATASET_DIR}"
fi

#################### 3. Get truth variants ####################
### If this step returns the error:
###   TypeError: 'NoneType' object is not iterable
###
### then make sure CHR and CHR_PREFIX are correct and TRUTH_VCF is not empty.
###
if [ "$STEP3" == true ]; then
  echo "Getting truth variants..."
  rm -f "$VARIANT_DIR"/var_* "$VARIANT_DIR"/all_var
  parallel --joblog ./get_truth.log -j $THREADS \
    $PYPY $CLAIR GetTruth \
    --vcf_fn "$TRUTH_VCF" \
    --var_fn "$VARIANT_DIR"/var_{1} \
    --ref_fn "$REF" \
    --ctgName ${CHR_PREFIX}{1} \
    ::: ${CHR[@]}

  # merge all truth variants into a single file (named all_var)
  cat "${VARIANT_DIR}"/var_* > "${VARIANT_DIR}"/all_var
fi

#################### 4. Get random non-variant candidates ####################
if [ "$STEP4" == true ]; then
  echo "Getting random non-variant candidates..."
  rm -f "$CANDIDATE_DIR"/can_*
  parallel --joblog ./extract_variant_candidates.log -j $THREADS \
    "$PYPY $CLAIR ExtractVariantCandidates" \
    --bam_fn "$BAM" \
    --ref_fn "$REF" \
    --can_fn "$CANDIDATE_DIR"/can_{1} \
    --ctgName ${CHR_PREFIX}{1} \
    --gen4Training \
    ::: ${CHR[@]}
fi

#################### 5. Create tensors for truth variants ####################
if [ "$STEP5" == true ]; then
  echo "Creating tensors from truth variants for all depths..."
  rm -f "$TENSOR_VARIANT_DIR"/*/tensor_var_*
  parallel --joblog ./create_tensor_var.log -j $THREADS \
    "$PYPY $CLAIR CreateTensor" \
    --bam_fn "$SUBSAMPLED_BAMS_DIR"/{1}.bam \
    --ref_fn "$REF" \
    --can_fn "$VARIANT_DIR"/var_{2} \
    --minCoverage $MINIMUM_COVERAGE \
    --tensor_fn "$TENSOR_VARIANT_DIR"/{1}/tensor_var_{2} \
    --ctgName ${CHR_PREFIX}{2} \
    ::: ${DEPTHS[@]} ::: ${CHR[@]}
fi

#################### 6. Create tensors for non-variants ####################
if [ "$STEP6" == true ]; then
  echo "Creating tensors for non-variants for all depths..."
  rm -f "$TENSOR_CANDIDATE_DIR"/*/tensor_can_*
  parallel --joblog ./create_tensor_can.log -j $THREADS \
    "$PYPY $CLAIR CreateTensor" \
    --bam_fn "$SUBSAMPLED_BAMS_DIR"/{1}.bam \
    --ref_fn "$REF" \
    --can_fn "$CANDIDATE_DIR"/can_{2} \
    --minCoverage $MINIMUM_COVERAGE \
    --tensor_fn "$TENSOR_CANDIDATE_DIR"/{1}/tensor_can_{2} \
    --ctgName ${CHR_PREFIX}{2} \
    ::: ${DEPTHS[@]} ::: ${CHR[@]}
fi

#################### 7. Merge truth variants and non-variants ####################
if [ "$STEP7" == true ]; then
  echo "Merging all truth variants and non-variants in pairs..."
  rm -f "$TENSOR_PAIR_DIR"/*/tensor_pair_*
  parallel --joblog ./create_tensor_pair.log -j $THREADS \
    "$PYPY $CLAIR PairWithNonVariants" \
    --tensor_can_fn "$TENSOR_CANDIDATE_DIR"/{1}/tensor_can_{2} \
    --tensor_var_fn "$TENSOR_VARIANT_DIR"/{1}/tensor_var_{2} \
    --output_fn "$TENSOR_PAIR_DIR"/{1}/tensor_pair_{2} \
    --amp 2 \
    ::: ${DEPTHS[@]} ::: ${CHR[@]}
fi

#################### 8. Shuffle, split and compress the tensors ####################
if [ "$STEP8" == true ]; then
  echo "Shuffle, split and compress the tensors..."
  ls "$DATASET_DIR"/tensor_pair/*/tensor_pair* \
    | parallel --joblog ./uncompress_tensors.log -j $THREADS_LOW \
               -N2 --line-buffer --shuf --verbose --compress stdbuf -i0 -o0 -e0 \
               pigz -p4 -dc ::: \
    | parallel --joblog ./round_robin_cat.log -j $THREADS \
               --line-buffer --pipe -N1000 --no-keep-order --round-robin --compress \
               split - -l $ESTIMATED_SPLIT_NO_OF_LINES \
                     --filter="'shuf | pigz -p4 > \$FILE.gz'" \
                     -d "$SHUFFLED_TENSORS_DIR"/split_{#}_
fi

#################### 9. Create splited binaries ####################
if [ "$STEP9" == true ]; then
  echo "Creating splitted binaries..."
  ls "$SHUFFLED_TENSORS_DIR"/split_* \
    | parallel --joblog ./tensor2Bin.log -j $THREADS_LOW \
      "python $CLAIR Tensor2Bin" \
      --tensor_fn {} \
      --var_fn "$VARIANT_DIR"/all_var \
      --bin_fn "$BINS_DIR"/{/.}.bin \
      --allow_duplicate_chr_pos
fi

#################### 10. Merge binaries into a single binary ####################
if [ "$STEP10" == true ]; then
  echo "Combining binaries..."
  cur_dir=$(pwd)
  cd "$DATASET_DIR"
  python $CLAIR CombineBins
  cd $cur_dir
  # result should be in ${DATASET_DIR}/tensor.bin
fi

#################### TRAIN ####################
### If you see the following error:
###  ...
###        batch_size = np.shape(next_x_batch)[0]
###  IndexError: tuple index out of range
###
### then that means the batch size in Clair/shared/param.py is too large
### for the test dataset. Try setting trainBatchSize to 1 to test this step.
###
if [ "$TRAIN" == true ]; then
  # set which gpu to use (for this test script, set none)
  export CUDA_VISIBLE_DEVICES=""
  # CLR modes: "tri", "tri2" or "exp" (we suggest using "tri2")
  CLR_MODE=tri2

  python $CLAIR train_clr \
         --bin_fn "$DATASET_DIR"/tensor.bin \
         --ochk_prefix "$MODEL" \
         --clr_mode "$CLR_MODE"
fi
