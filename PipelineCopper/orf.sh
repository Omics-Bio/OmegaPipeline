#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard

/lustre/usr/local/usp/metaomics/software/FragGeneScan1.20/run_FragGeneScan.pl \
-genome=${seq} \
-out=${output} \
-complete=0 \
-train=illumina_10 \
-thread=32
