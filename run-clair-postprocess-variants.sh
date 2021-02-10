#!/bin/bash
#SBATCH --job-name=clair-postprocess-variants
#SBATCH --output=clair-postprocess-variants-%j.out
#SBATCH --error=clair-postprocess-variants-%j.err
#SBATCH --time=0:10:00
#SBATCH --cpus-per-task=4
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aa5525@nyu.edu

module purge
source activate clair

CLAIR_DIR="/scratch/aa5525/clair"
CLAIR="$CLAIR_DIR/Clair/clair.py"
VCF_DIR="$CLAIR_DIR/data/vcf"
VCF="$VCF_DIR/clair_snp_and_indel.SRR062634"  # without extension

zcat "${VCF}.vcf.gz" | python $CLAIR overlap_variant | bgziptabix "${VCF}.filtered.vcf.gz"
