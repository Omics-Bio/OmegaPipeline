#!/bin/bash

##################################################################
# Parameters Needed to Be Speicified
# InputFile/InputFile2:
# # If it is interleaved format, only one input file is accepted, 
# # and assign "EMPTY" to "InputFile2"
# # If paired end reads in two separate files, provide pathes to 
# # "InputFile" and "InputFile2"
# WorkingDirectory:
# # This is will be the directory to store all the intermediate 
# # results by this pipeline. The final assembled contigs will be
# # in "Omega" folder
# SingleRead:
# # Either "YES" or "NO"
# NumThreads:
# # The number of available threads on each nodes
# TargetName:
# # The prefix for the file that stores final assembled contigs
##################################################################
InputFile="xxx.fastq"
InputFile2="EMPTY"
WorkingDirectory="/xxx/xxx/WorkingDirectory"
SingleRead="NO"
NumThreads="32"
TargetName="X41"
Account="XXXXXXXXX"
##################################################################
# Paths to the necessary programs
##################################################################
PathHero="/xxxx/software/pipelineOmega/Hero/Hero"
PathOmega="/xxxx/software/pipelineOmega/Omega3/"
PathBbmap="/xxxx/software/pipelineOmega/bbmap/"
PathPython="python"

##################################################################
# Parameters for Heterogeneity Remover (Can leave them unchanged)
##################################################################
Kmer="31"
Mismatch="2"
MinOverlapLength="50"
CoverageDepth="0"

##################################################################
# Parameters used inside (DO NOT CHANGE)
##################################################################
PathPipeline=${WorkingDirectory}/Scripts/
SplitFolder=${WorkingDirectory}/Split
Filename="Split"
SizePerFile="2000" #size in Mb
ErrorCorrection="NO"
ApplyHero="YES"


##################################################################
## function to check if the submitted job fininshed or not
## based on the "mark" file in the target folder
# two parameters needed
# $1 is the workingdirectory of hero
# $2 is the number of splits
##################################################################
function checkResults(){
	#TempNum=`ls ${1}/*mark | wc -l`
	#if [ ${TempNum} != ${2} ]; then
		#return 1
	#fi
	TempNum=0
	UpperBound=`expr ${2} - 1`
	for ((i=0;i<=UpperBound;i++))
	do
		namenew=`printf "%02d" ${i}`
		if [ -f ${1}/${namenew}.mark ]; then
			Line=`tail -n 1 ${1}/${namenew}.mark`
			if [ ${Line} == "DONE" ]; then
				TempNum=`expr ${TempNum} + 1`
			fi
		fi
	done
	if [ ${TempNum} == ${2} ]; then
		return 0
	fi
	return 1
}

if [ "${1}" == "OmegaDone" ]
	then
	cp ${WorkingDirectory}/Omega/assembly/${TargetName}_contigsFinal.fasta ${WorkingDirectory}/
	echo "Omega Completed at $(date)." >> ${WorkingDirectory}/Omega.log
	echo "The assembled contigs is in ${WorkingDirectory}." >> ${WorkingDirectory}/Omega.log
	echo "The name is ${TargetName}_contigs.fasta" >> ${WorkingDirectory}/Omega.log
fi


##################################################################
## This is the third step:
## Concatenate results from Hero
## Call Omega 3
##################################################################
if [ "${1}" == "Merge" ]; then
	numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
	numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
	# check if all Hero done or not
	checkResults ${WorkingDirectory}/Hero/merged ${numOfMergedSplits}
	returnvalue1=$?
	checkResults ${WorkingDirectory}/Hero/unmerged ${numOfUnmergedSplits}
	returnvalue2=$?

	if (( ${returnvalue1} + ${returnvalue2} != 0 )); then
		exit
	fi

	echo "Finish Hero Jobs at $(date)." >> ${WorkingDirectory}/Omega.log
	echo "" >> ${WorkingDirectory}/Omega.log
	echo "Start Concatenating Jobs at $(date)." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Merge" ]; then
		rm -r ${WorkingDirectory}/Merge
		mkdir ${WorkingDirectory}/Merge
	else
		mkdir ${WorkingDirectory}/Merge
	fi
	countMerged=`ls -1 ${WorkingDirectory}/Hero/merged/*fasta 2>/dev/null | wc -l`
	countUnmerged=`ls -1 ${WorkingDirectory}/Hero/unmerged/*fasta 2>/dev/null | wc -l`
	if (( ${countMerged}>0 )); then
		AllMerged=(${WorkingDirectory}/Hero/merged/*fasta)
		cat ${AllMerged} > ${WorkingDirectory}/Merge/SingleEnd.fasta
	fi
	if (( ${countUnmerged}>0 )); then
		AllUnmerged=(${WorkingDirectory}/Hero/unmerged/*fasta)
		cat ${AllUnmerged} > ${WorkingDirectory}/Merge/PairEnd.fasta
	fi
	echo "Finish Concatenating Jobs at $(date)." >> ${WorkingDirectory}/Omega.log
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Storm-Aligning Jobs." >> ${WorkingDirectory}/Omega.log
	echo "Submit Omega Jobs..." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Omega" ]; then
		rm -r ${WorkingDirectory}/Omega
		mkdir ${WorkingDirectory}/Omega
	else
		mkdir ${WorkingDirectory}/Omega
	fi
	qsub \
-A ${Account} \
-e "${WorkingDirectory}/Omega/ErrOmega.log" \
-o "${WorkingDirectory}/Omega/OutOmega.log" \
-v PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Omega,\
InputReads=${WorkingDirectory}/Merge,\
PathOmega=${PathOmega},\
NumThreads=${NumThreads},\
TargetName=${TargetName},\
Filename=${Filename} \
${PathPipeline}/3_omega.sh \
>> ${WorkingDirectory}/Omega.log 
	exit
fi


##################################################################
## This is the second step:
## Error correction
## Heterogeneity remover
##################################################################
if [ "${1}" == "Hero" ]
	then
	# run Heterogeneity remover
	echo "Finish Triming, Filtering, Merging, and Spliting Jobs at $(date)." >> ${WorkingDirectory}/Omega.log
	echo "" >> ${WorkingDirectory}/Omega.log
	echo "Submit Hero Jobs..." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Hero" ]; then
		rm -r ${WorkingDirectory}/Hero/
		mkdir ${WorkingDirectory}/Hero
		mkdir ${WorkingDirectory}/Hero/merged
		mkdir ${WorkingDirectory}/Hero/unmerged
	else
		mkdir ${WorkingDirectory}/Hero
		mkdir ${WorkingDirectory}/Hero/merged
		mkdir ${WorkingDirectory}/Hero/unmerged
	fi

	# get the number of splits
	numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
	numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`

	if [ ${ApplyHero} != "YES" ]; then
		if(( ${numOfMergedSplits} > 0 )); then
			for(( i=0; i<${numOfMergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				echo "DONE" > ${WorkingDirectory}/Hero/merged/${namenew}.mark
				cp ${WorkingDirectory}/Split/merged/${Filename}.${namenew}.fasta \
${WorkingDirectory}/Hero/merged/${Filename}_${namenew}.fasta
			done
		fi
		if(( ${numOfUnmergedSplits} > 0 )); then
			for(( i=0; i<${numOfUnmergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				echo "DONE" > ${WorkingDirectory}/Hero/unmerged/${namenew}.mark
				cp ${WorkingDirectory}/Split/unmerged/${Filename}.${namenew}.fasta \
${WorkingDirectory}/Hero/unmerged/${Filename}_${namenew}.fasta
			done
		fi
		${PathPipeline}/0_master.sh Merge
		exit
	fi

	# first run Hero on merged reads
	if(( ${numOfMergedSplits} > 0 )); then
		numOfMergedSplits=`expr ${numOfMergedSplits} - 1`
		qsub \
-A ${Account} \
-e "${WorkingDirectory}/Hero/merged/ErrHero.log" \
-o "${WorkingDirectory}/Hero/merged/OutHero.log" \
`if (( ${numOfMergedSplits} > 0 )); then echo "-J 0-${numOfMergedSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v SplitFolderMerged=${WorkingDirectory}/Split/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Split/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Split/merged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Hero/merged/,\
PathHero=${PathHero},\
Kmer=${Kmer},\
CoverageDepth=${CoverageDepth},\
Mismatch=${Mismatch},\
NumThreads=${NumThreads},\
MinOverlapLength=${MinOverlapLength} \
${PathPipeline}/2_hero.sh \
>> ${WorkingDirectory}/Omega.log
	fi

	# next run Hero on unmerged reads
	if(( ${numOfUnmergedSplits} > 0 )); then
		#echo "Number of unmerged splits: " ${numOfUnmergedSplits}
		numOfUnmergedSplits=`expr ${numOfUnmergedSplits} - 1`
		qsub \
-A ${Account} \
-e "${WorkingDirectory}/Hero/unmerged/ErrHero.log" \
-o "${WorkingDirectory}/Hero/unmerged/OutHero.log" \
`if (( ${numOfUnmergedSplits} > 0 )); then echo "-J 0-${numOfUnmergedSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v SplitFolderMerged=${WorkingDirectory}/Split/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Split/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Split/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Hero/unmerged/,\
PathHero=${PathHero},\
Kmer=${Kmer},\
Mismatch=${Mismatch},\
NumThreads=${NumThreads},\
MinOverlapLength=${MinOverlapLength} \
${PathPipeline}/2_hero.sh \
>> ${WorkingDirectory}/Omega.log
	fi
	exit
fi

##################################################################
## This is the first step including:
## Trimming by bbduk
## Filtering by bbduk
## merge overlapped paired end reads by bbmerge
## splitting by split_rename.py, which split both merged and unmerged reads
##   into multiple files with file size no larger than 2 GB
##################################################################
if [ "${1}" == "Start" ]
	then
	echo "Submit Triming, Filtering, Merging, and Spliting Jobs at $(date)." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Scripts" ]; then
		rm -r ${WorkingDirectory}/Scripts
		mkdir ${WorkingDirectory}/Scripts
	else
		mkdir ${WorkingDirectory}/Scripts
	fi
	AllScripts=`dirname $0`
	cp ${AllScripts}/* ${WorkingDirectory}/Scripts
	if [ -d "${WorkingDirectory}/Tfms" ]; then
		rm -r ${WorkingDirectory}/Tfms
		mkdir ${WorkingDirectory}/Tfms
	else
		mkdir ${WorkingDirectory}/Tfms
	fi
	qsub \
-A ${Account} \
-e "${WorkingDirectory}/Tfms/ErrTfms.log" \
-o "${WorkingDirectory}/Tfms/OutTfms.log" \
-v SplitFolder="${WorkingDirectory}/Split",\
Filename="${Filename}",\
InputFile="${InputFile}",\
InputFile2="${InputFile2}",\
SizePerFile=${SizePerFile},\
PathPipeline=${PathPipeline},\
PathBbmap="${PathBbmap}",\
PathPython="${PathPython}",\
ErrorCorrection="${ErrorCorrection}",\
SingleRead="${SingleRead}",\
WorkingDirectory="${WorkingDirectory}/Tfms",\
NumThreads="${NumThreads}" \
${PathPipeline}/1_trim_filter_merge_split.sh \
>> ${WorkingDirectory}/Omega.log
	exit
fi
