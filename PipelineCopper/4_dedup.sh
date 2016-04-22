#!/bin/bash

#PBS -l walltime=12:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard
#PBS -r y

namenew=`printf "%02d" ${PBS_ARRAY_INDEX}`

info=(${InputPath}/${Filename}_[0-9]*.fasta)
sub=$(echo ${info[@]} | tr " " ",")

aprun -d ${NumThreads} \
${PathStorm} -i RemoveContainedReads \
--query ${InputPath}/${Filename}_${namenew}.fasta \
--subject ${sub} \
-ht single \
-l 40 -k 39 -m 0 -t ${NumThreads} -z `expr ${NumThreads} \* 2000` \
--out ${WorkingDirectory}/${Filename}_${namenew}.fasta \
&> ${WorkingDirectory}/${Filename}_${namenew}.log

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/0_master.sh "DedupDone"
