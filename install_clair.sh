# Create and activate the environment named clair
conda create -n clair tensorflow=1.13.1 python=3.7
conda activate clair

# install pypy and packages on clair environemnt
conda install -y -c conda-forge pypy3.6
pypy3 -m ensurepip
pypy3 -m pip install intervaltree==3.0.2
pypy3 -m pip install gcc7

# install python packages on clair environment
python -m pip install numpy==1.18.0 blosc==1.8.3 intervaltree==3.0.2 pysam==0.15.3 matplotlib==3.1.2
conda install -y -c anaconda pigz==2.4
conda install -y -c conda-forge parallel=20191122 zstd=1.4.4
conda install -y -c bioconda samtools=1.10 vcflib=1.0.0 bcftools=1.10.2

