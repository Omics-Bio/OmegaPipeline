#!/bin/bash

#SBATCH -N 1
#SBATCH -t 03:00:00

namenew=`printf "%02d" ${SLURM_ARRAY_TASK_ID}`

info=(${InputPath}/${Filename}_[0-9]*.fasta)
sub=$(echo ${info[@]} | tr " " ",")

${PathStorm} -i RemoveContainedReads \
--query ${InputPath}/${Filename}_${namenew}.fasta \
--subject ${sub} \
-ht single \
-l 40 -k 39 -m 0 -t ${NumThreads} -z `expr ${NumThreads} \* 2000` \
--out ${WorkingDirectory}/${Filename}_${namenew}.fasta \
&> ${WorkingDirectory}/${Filename}_${namenew}.log

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/0_master.sh "DedupDone"