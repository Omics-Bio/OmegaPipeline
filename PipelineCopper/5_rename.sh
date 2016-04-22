#!/bin/bash

#PBS -l walltime=01:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard
namenew="00"

awk 'BEGIN{i=0}/^>/{print ">" i++; next}{print}' \
< ${InputPath}/${Filename}_${namenew}.fasta > \
${WorkingDirectory}/${Filename}_${namenew}.fasta

for ((i=1;i<${NumOfSplits};i++)); do
	StartId=`tail -n 2 ${WorkingDirectory}/${Filename}_${namenew}.fasta | head -n 1`
	StartId=`echo ${StartId:1}`
	StartId=`expr ${StartId} + 1`
	namenew=`printf "%02d" ${i}`
	awk -v var=${StartId} 'BEGIN{i=var}/^>/{print ">" i++; next}{print}' \
< ${InputPath}/${Filename}_${namenew}.fasta > \
${WorkingDirectory}/${Filename}_${namenew}.fasta
done

echo "DONE" > ${WorkingDirectory}/${Filename}.mark

${PathPipeline}/0_master.sh "RenameDone"