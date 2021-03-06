#!/bin/bash
#PBS -l walltime=12:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard
#PBS -r y
ls ${SplitFolderMerged}/${Filename}.[0-9]*.fasta &> /dev/null
mergedCode=$?
ls ${SplitFolderUnmerged}/${Filename}.[0-9]*.fasta &> /dev/null
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
	merged=(${SplitFolderMerged}/${Filename}.[0-9]*.fasta)
	sub=$(echo ${merged[@]} | tr " " ",")
else
	sub=""
fi

if [ ${unmergedCode} == 0 ]; then
	unmerged=(${SplitFolderUnmerged}/${Filename}.[0-9]*.fasta)
	sub1=$(echo ${unmerged[@]} | tr " " ",")
	if [ "${sub}" == "" ]; then
		sub=$sub1
	else
		sub=${sub}","${sub1}
	fi
fi

#echo ${PBS_ARRAY_INDEX}

namenew=`printf "%02d" ${PBS_ARRAY_INDEX}`

numBlockSubject=`expr ${NumThreads} \* 6000`
numBlockQuery=`expr ${NumThreads} \* 2000`

if [ "${SplitFolderUnmerged}" == "${Target}" ]; then
	aprun -d ${NumThreads} \
${PathHero} \
-s ${sub} \
-q ${Target}/${Filename}.${namenew}.fasta \
-k ${Kmer} -m ${Mismatch} -i 0 -t ${NumThreads} \
-z ${numBlockSubject} -y ${numBlockQuery} \
-o ${WorkingDirectory} \
-l ${MinOverlapLength} -a g \
--suffix ${Filename}_${namenew} -c 0.15 --covinfo --covfilter ${CoverageDepth} \
> ${WorkingDirectory}/${Filename}_${namenew}.log
else
	aprun -d ${NumThreads} \
${PathHero} \
-s ${sub} \
-q ${Target}/${Filename}.${namenew}.fasta \
-k ${Kmer} -m ${Mismatch} -i 0 -t ${NumThreads} \
-z ${numBlockSubject} -y ${numBlockQuery} \
-o ${WorkingDirectory} \
-l ${MinOverlapLength} -a g \
--singleReads \
--suffix ${Filename}_${namenew} -c 0.15 --covinfo --covfilter ${CoverageDepth} \
> ${WorkingDirectory}/${Filename}_${namenew}.log
fi

echo "DONE" > ${WorkingDirectory}/${namenew}.mark

${PathPipeline}/0_master.sh Merge
