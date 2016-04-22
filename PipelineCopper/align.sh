#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard
#PBS -r y

namenew=`printf "%02d" ${PBS_ARRAY_INDEX}`

info=(${InputPath}/${Filename}_[0-9]*.fasta)
sub=$(echo ${info[@]} | tr " " ",")

aprun -d ${NumThreads} \
${PathStorm} -i ConstructOverlapGraph -ht single \
--TransitiveReduction \
--query ${InputPath}/${Filename}_${namenew}.fasta \
--subject ${sub} \
--out ${WorkingDirectory}/${Filename}_${namenew}.align \
-l 40 -k 39 -m 0 \
-t ${NumThreads} -z `expr ${NumThreads} \* 2000` \
&> ${WorkingDirectory}/${Filename}_${namenew}.log

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/master.sh "AlignDone"
