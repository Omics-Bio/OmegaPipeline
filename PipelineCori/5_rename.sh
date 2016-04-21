#!/bin/bash

#SBATCH -N 1
#SBATCH -t 00:30:00

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