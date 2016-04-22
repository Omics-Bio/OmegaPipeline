#!/bin/bash

#SBATCH -N 1
#SBATCH -t 03:00:00

ls ${SplitFolderMerged}/${Filename}_[0-9]*.fasta &> /dev/null
mergedCode=$?
ls ${SplitFolderUnmerged}/${Filename}_[0-9]*.fasta &> /dev/null
unmergedCode=$?

if [ ${mergedCode} != 0 -a ${unmergedCode} != 0 ]; then
	echo "Split folder is empty."
	exit 1
fi

if [ ${mergedCode} != 0 -a "${SplitFolderMerged}" == "${Target}" ]; then
	echo ${Target} " is empty."
	exit 1
fi

if [ ${unmergedCode} != 0 -a "${SplitFolderUnmerged}" == "${Target}" ]; then
	echo ${Target} " is empty."
	exit 1
fi

sub=""
if [ ${mergedCode} == 0 ]; then
	merged=(${SplitFolderMerged}/${Filename}_[0-9]*.fasta)
	sub=$(echo ${merged[@]} | tr " " ",")
else
	sub=""
fi

if [ ${unmergedCode} == 0 ]; then
	unmerged=(${SplitFolderUnmerged}/${Filename}_[0-9]*.fasta)
	sub1=$(echo ${unmerged[@]} | tr " " ",")
	if [ "${sub}" == "" ]; then
		sub=$sub1
	else
		sub=${sub}","${sub1}
	fi
fi

#echo ${sub}

namenew=`printf "%02d" ${SLURM_ARRAY_TASK_ID}`

${PathStorm} \
-i MergePairedEndReads \
--query ${Target}/${Filename}_${namenew}.fasta \
--subject ${sub} \
-ht single \
--orient 2 \
-mr 0 -ll 31 -rl 31 -ol 80 -k 31 -c 1 -b 0.6 \
-t ${NumThreads} -z `expr ${NumThreads} \* 2000` \
--out ${WorkingDirectory}/${Filename}_${namenew}_ \
&> ${WorkingDirectory}/${Filename}_${namenew}.log

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/0_master.sh "MergeDone"
