
DATA_DIR="$SCRATCH/clair/data"
mkdir -p "$DATA_DIR" && cd "$DATA_DIR"

# Download and extract the testing dataset
wget 'http://www.bio8.cs.hku.hk/testingData.tar'
tar -xf testingData.tar

# Create a folder for outputs
mkdir training
