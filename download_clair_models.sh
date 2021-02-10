
MODEL_DIR="$SCRATCH/clair/models"
mkdir -p "$MODEL_DIR" && cd "$MODEL_DIR"

# download the trained model for ONT
mkdir ont && cd ont
wget http://www.bio8.cs.hku.hk/clair_models/ont/122HD34.tar
tar -xf 122HD34.tar
cd ../

# download the trained model for PacBio CCS
mkdir pacbio && cd pacbio
wget http://www.bio8.cs.hku.hk/clair_models/pacbio/ccs/15.tar
tar -xf 15.tar
cd ../

# download the trained model for Illumina
mkdir illumina && cd illumina
wget http://www.bio8.cs.hku.hk/clair_models/illumina/12345.tar
tar -xf 12345.tar
cd ../
