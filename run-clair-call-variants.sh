
CLAIR_DIR="/scratch/aa5525/clair"
CLAIR="$CLAIR_DIR/Clair/clair.py"

SAMPLE_NAME="HG019"
MODEL="$CLAIR_DIR/models/illumina/model"
VCF="$CLAIR_DIR/data/clair.NA12878_S1.hg19.chr20.vcf"

test_dir="/scratch/aa5525/deepvariant/quickstart-testdata"
REF="${test_dir}/quickstart-testdata_ucsc.hg19.chr20.unittest.fasta"
BAM="${test_dir}/quickstart-testdata_NA12878_S1.chr20.10_10p1mb.bam"
CAPTURE_BED="${test_dir}/quickstart-testdata_test_nist.b37_chr20_100kbp_at_10mb.bed"
CONTIG_NAME="chr20"

N_THREADS=8
QUAL=100

python $CLAIR callVarBam \
       --sampleName "$SAMPLE_NAME" \
       --chkpnt_fn "$MODEL" \
       --bam_fn "$BAM" \
       --ref_fn "$REF" \
       --bed_fn "$BED" \
       --call_fn "$VCF" \
       --ctgName "$CONTIG_NAME" \
       --pysam_for_all_indel_bases \
       --threads $N_THREADS \
       --qual $QUAL
