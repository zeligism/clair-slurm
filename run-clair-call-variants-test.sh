
CLAIR_DIR="/scratch/aa5525/clair"
CLAIR="$CLAIR_DIR/Clair/clair.py"

SAMPLE_NAME="HG001"
MODEL="$CLAIR_DIR/models/illumina/model"
BAM="$CLAIR_DIR/data/testingData/chr21/chr21.bam"
REF="$CLAIR_DIR/data/testingData/chr21/chr21.fa"
VCF="$CLAIR_DIR/data/testingData/chr21.vcf"

N_THREADS=8
QUAL=100

CTG_NAME=chr21
CTG_START=10269870
CTG_END=46672937

python $CLAIR callVarBam \
       --sampleName "$SAMPLE_NAME" \
       --chkpnt_fn "$MODEL" \
       --bam_fn "$BAM" \
       --ref_fn "$REF" \
       --call_fn "$VCF" \
       --pysam_for_all_indel_bases \
       --threads $N_THREADS \
       --qual $QUAL \
       --ctgName "$CTG_NAME" \
       --ctgStart $CTG_START \
       --ctgEnd $CTG_END
