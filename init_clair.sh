# clone Clair
git clone --depth 1 https://github.com/HKU-BAL/Clair.git
cd Clair
chmod +x clair.py
export PATH=`pwd`":$PATH"  # XXX: does not export outside shell script

# store clair.py PATH into $CLAIR variable
CLAIR=`which clair.py`
echo $CLAIR

# run clair like this afterwards
python $CLAIR --help
