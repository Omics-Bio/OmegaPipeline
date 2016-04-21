#!/bin/bash

#SBATCH -N 1
#SBATCH -t 06:00:00

namenew=`printf "%02d" ${SLURM_ARRAY_TASK_ID}`

info=(${InputPath}/${Filename}_[0-9]*.fasta)
sub=$(echo ${info[@]} | tr " " ",")

${PathStorm} -i ConstructOverlapGraph -ht single \
--TransitiveReduction \
--query ${InputPath}/${Filename}_${namenew}.fasta \
--subject ${sub} \
--out ${WorkingDirectory}/${Filename}_${namenew}.align \
-l 40 -k 39 -m 0 \
-t ${NumThreads} -z `expr ${NumThreads} \* 2000` \
&> ${WorkingDirectory}/${Filename}_${namenew}.log

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/0_master.sh "AlignDone"
