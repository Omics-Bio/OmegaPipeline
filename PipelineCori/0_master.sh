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
InputFile="/global/projectb/scratch/pcl/MetaGenomicsAssembly/cami_bbqc/xuan/cori/test/test.fq"
InputFile2="EMPTY"
WorkingDirectory="/global/projectb/scratch/pcl/MetaGenomicsAssembly/cami_bbqc/xuan/cori/test"
SingleRead="NO"
NumThreads="32"
TargetName="Test"

##################################################################
# Pathes to the necessary programs
##################################################################
PathHero="/global/u2/p/pcl/Software/hero/slehea"
PathStorm="/global/u2/p/pcl/Software/align_test/Release/align_test"
PathOmega="/global/u2/p/pcl/Software/omega2_v1.4/omega2"
PathBbmap="/global/u2/p/pcl/Software/bbmap"
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
QueueType="-p regular "

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
	rm -r -f ${WorkingDirectory}/Tfms
	rm -r -f ${WorkingDirectory}/Split
	rm -r -f ${WorkingDirectory}/Rename
	rm -r -f ${WorkingDirectory}/Merge
	rm -r -f ${WorkingDirectory}/Hero
	rm -r -f ${WorkingDirectory}/Dedup
	rm -r -f ${WorkingDirectory}/Align
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Omega Completed." >> ${WorkingDirectory}/Omega.log
fi


##################################################################
## This is the seventh step:
## Apply Omega to get the assembled contigs
##################################################################
if [ "${1}" == "AlignDone" ]
	then
	# check if all Align done or not
	NumOfSplits=`ls ${WorkingDirectory}/Rename/${Filename}*.fasta | wc -l`
	checkResults ${WorkingDirectory}/Align ${NumOfSplits}
	returnvalue=$?
	# run Omega
	if [ "${returnvalue}" == 0 ]; then
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Storm-Aligning Jobs." >> ${WorkingDirectory}/Omega.log
		echo "Submit Omega Jobs..." >> ${WorkingDirectory}/Omega.log
		if [ -d "${WorkingDirectory}/Omega" ]; then
			rm -r ${WorkingDirectory}/Omega
			mkdir ${WorkingDirectory}/Omega
		else
			mkdir ${WorkingDirectory}/Omega
		fi
		sbatch \
-D ${WorkingDirectory}/Omega ${QueueType}\
-e "ErrOmega.log" \
-o "OutOmega.log" \
--export=PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Omega,\
InputReads=${WorkingDirectory}/Rename,\
InputAlign=${WorkingDirectory}/Align,\
PathOmega=${PathOmega},\
NumThreads=${NumThreads},\
TargetName=${TargetName},\
Filename=${Filename} \
${PathPipeline}/7_omega.sh \
>> ${WorkingDirectory}/Omega.log 
	fi
	exit
fi


##################################################################
## This is the sixth step:
## Construct the overlap graph
##################################################################
if [ "${1}" == "RenameDone" ]
	then
	# run overlap graph construction
	NumOfSplits=`ls ${WorkingDirectory}/Rename/${Filename}*.fasta | wc -l`
	NumOfSplits=`expr ${NumOfSplits} - 1`
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Storm-Renaming Jobs." >> ${WorkingDirectory}/Omega.log
	echo "" >> ${WorkingDirectory}/Omega.log
	echo "Submit Storm-Aligning Jobs..." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Align" ]; then
		rm -r ${WorkingDirectory}/Align
		mkdir ${WorkingDirectory}/Align
	else
		mkdir ${WorkingDirectory}/Align
	fi
	sbatch \
-D ${WorkingDirectory}/Align ${QueueType}\
-e "ErrAlign.log" \
-o "OutAlign.log" \
-a 0-${NumOfSplits} \
--export=PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Align,\
InputPath=${WorkingDirectory}/Rename/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads},\
Filename=${Filename} \
${PathPipeline}/6_align.sh \
>> ${WorkingDirectory}/Omega.log 
	exit
fi

##################################################################
## This is the fifth step:
## Rename all the reads
##################################################################
if [ "${1}" == "DedupDone" ]; then
	# check if all Dedup done or not
	NumOfSplits=`ls ${WorkingDirectory}/Merge/${Filename}*.fasta | wc -l`
	checkResults ${WorkingDirectory}/Dedup ${NumOfSplits}
	returnvalue=$?
	# rename all the reads
	if [ "${returnvalue}" == 0 ]; then
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Storm-Dedup Jobs." >> ${WorkingDirectory}/Omega.log
		echo "" >> ${WorkingDirectory}/Omega.log
		echo "Submit Storm-Renaming Jobs..." >> ${WorkingDirectory}/Omega.log
		if [ -d "${WorkingDirectory}/Rename" ]; then
			rm -r ${WorkingDirectory}/Rename
			mkdir ${WorkingDirectory}/Rename
		else
			mkdir ${WorkingDirectory}/Rename
		fi
	sbatch \
-D ${WorkingDirectory}/Rename ${QueueType}\
-e "ErrRename.log" \
-o "OutRename.log" \
--export=PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Rename,\
InputPath=${WorkingDirectory}/Dedup/,\
Filename=${Filename},\
NumOfSplits=${NumOfSplits} \
${PathPipeline}/5_rename.sh \
>> ${WorkingDirectory}/Omega.log 
	fi
	exit
fi

##################################################################
## This is the fourth step:
## Remove contained reads
##################################################################
if [ "${1}" == "HeroDone" ]; then
	# run contained reads remover
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Hero/Merging/Moving Jobs." >> ${WorkingDirectory}/Omega.log
	echo "Submit Storm-Dedup Jobs..." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Dedup" ]; then
		rm -r ${WorkingDirectory}/Dedup/
		mkdir ${WorkingDirectory}/Dedup
	else
		mkdir ${WorkingDirectory}/Dedup
	fi
	NumOfSplits=`ls ${WorkingDirectory}/Merge/${Filename}*.fasta | wc -l`
	NumOfSplits=`expr ${NumOfSplits} - 1`
	sbatch \
-D ${WorkingDirectory}/Dedup ${QueueType}\
-e "ErrDedup.log" \
-o "OutDedup.log" \
-a 0-${NumOfSplits} \
--export=PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Dedup,\
InputPath=${WorkingDirectory}/Merge,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads},\
Filename=${Filename} \
${PathPipeline}/4_dedup.sh \
>> ${WorkingDirectory}/Omega.log 
	exit
fi


##################################################################
## This is a post step for the third step:
## merge the output from storm
## create soft links to the merged corrected reads
##################################################################
if [ "${1}" == "MergeDone" ]; then
	#rename the results from STORM_merge
	numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
	checkResults ${WorkingDirectory}/Merge/ ${numOfUnmergedSplits}
	returnvalue=$?

	if [ "${returnvalue}" == 0 ]; then
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Merging Jobs." >> ${WorkingDirectory}/Omega.log
		echo "" >> ${WorkingDirectory}/Omega.log
		for(( i=0; i<${numOfUnmergedSplits}; i++ )); do
			newname=`printf "%02d" ${i}`
			if [ -f ${WorkingDirectory}/Merge/${Filename}_${newname}_merged.fasta -a \
-f ${WorkingDirectory}/Merge/${Filename}_${newname}_notmerged.fasta ]; then
				cat ${WorkingDirectory}/Merge/${Filename}_${newname}_merged.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}_notmerged.fasta \
> ${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
				rm ${WorkingDirectory}/Merge/${Filename}_${newname}_merged.fasta
				rm ${WorkingDirectory}/Merge/${Filename}_${newname}_notmerged.fasta
			elif [ -f ${WorkingDirectory}/Merge/${Filename}_${newname}_merged.fasta ]; then
				mv ${WorkingDirectory}/Merge/${Filename}_${newname}_merged.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
			elif [ -f ${WorkingDirectory}/Merge/${Filename}_${newname}_notmerged.fasta ]; then
				mv ${WorkingDirectory}/Merge/${Filename}_${newname}_notmerged.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
			fi
		done

		#move the merged results from Hero to this folder, and rename them
		numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
		for(( i=0; i<${numOfMergedSplits}; i++ )); do
			newname=`printf "%02d" ${i}`
			newId=`expr ${numOfUnmergedSplits} + ${i}`
			newId=`printf "%02d" ${newId}`
			ln -s ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newId}.fasta
		done
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
		${PathPipeline}/0_master.sh "HeroDone"
		exit
	fi
fi


##################################################################
## This is the third step:
## Using Strom to merge untouchable paired end reads
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

	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Hero Jobs." >> ${WorkingDirectory}/Omega.log
	echo "" >> ${WorkingDirectory}/Omega.log
	echo "Submit Storm-Merge Jobs." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Merge" ]; then
		rm -r ${WorkingDirectory}/Merge
		mkdir ${WorkingDirectory}/Merge
	else
		mkdir ${WorkingDirectory}/Merge
	fi
	countMerged=`ls -1 ${WorkingDirectory}/Hero/merged/*fasta 2>/dev/null | wc -l`
	countUnmerged=`ls -1 ${WorkingDirectory}/Hero/unmerged/*fasta 2>/dev/null | wc -l`
	if (( ${countMerged}>0 && ${countUnmerged}>0 )); then
		SizeMergedFiles=`ls -l ${WorkingDirectory}/Hero/merged/*fasta | awk '{total += $5}END{print total}'`
		SizeUnmergedFiles=`ls -l ${WorkingDirectory}/Hero/unmerged/*fasta | awk '{total += $5}END{print total}'`
		if (( ${SizeUnmergedFiles}*9 > ${SizeMergedFiles} )); then
			# start the merge
			numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
			numOfUnmergedSplits=`expr ${numOfUnmergedSplits} - 1`
			echo ${numOfUnmergedSplits}
			sbatch \
-D ${WorkingDirectory}/Merge ${QueueType}\
-e "ErrMerge.log" \
-o "OutMerge.log" \
-a 0-${numOfUnmergedSplits} \
--export=SplitFolderMerged=${WorkingDirectory}/Hero/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Hero/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Hero/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Merge/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads} \
${PathPipeline}/2_storm.sh \
>> ${WorkingDirectory}/Omega.log
		else
			#move to Merge and rename
			numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
			for(( i=0; i<${numOfUnmergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				ln -s ${WorkingDirectory}/Hero/unmerged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
			done
			numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
			for(( i=0; i<${numOfMergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				newId=`expr ${numOfUnmergedSplits} + ${i}`
				newId=`printf "%02d" ${newId}`
				ln -s ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newId}.fasta
			done
			echo Time is $(date) >> ${WorkingDirectory}/Omega.log
			echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
			${PathPipeline}/0_master.sh "HeroDone"
		fi
	elif (( ${countMerged}>0 )); then
		numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
		for(( i=0; i<${numOfMergedSplits}; i++ )); do
			newname=`printf "%02d" ${i}`
			ln -s ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
		done
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
		${PathPipeline}/0_master.sh "HeroDone"
	elif (( ${countUnmerged}>0 )); then
		numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
		numOfUnmergedSplits=`expr ${numOfUnmergedSplits} - 1`
		sbatch \
-D ${WorkingDirectory}/Merge ${QueueType}\
-e "ErrMerge.log" \
-o "OutMerge.log" \
-a 0-${numOfUnmergedSplits} \
--export=SplitFolderMerged=${WorkingDirectory}/Hero/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Hero/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Hero/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Merge/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads} \
${PathPipeline}/2_storm.sh \
>> ${WorkingDirectory}/Omega.log
	fi
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
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Triming, Filtering, Merging, and Spliting Jobs..." >> ${WorkingDirectory}/Omega.log
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
		sbatch \
-D ${WorkingDirectory}/Hero/merged ${QueueType}\
-e "ErrHero.log" \
-o "OutHero.log" \
-a 0-${numOfMergedSplits} \
--export=SplitFolderMerged=${WorkingDirectory}/Split/merged,\
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
		numOfUnmergedSplits=`expr ${numOfUnmergedSplits} - 1`
		sbatch \
-D ${WorkingDirectory}/Hero/unmerged ${QueueType}\
-e "ErrHero.log" \
-o "OutHero.log" \
-a 0-${numOfUnmergedSplits} \
--export=SplitFolderMerged=${WorkingDirectory}/Split/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Split/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Split/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Hero/unmerged/,\
PathHero=${PathHero},\
Kmer=${Kmer},\
CoverageDepth=${CoverageDepth},\
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
	echo Time is $(date) > ${WorkingDirectory}/Omega.log
	echo "Submit Triming, Filtering, Merging, and Spliting Jobs..." >> ${WorkingDirectory}/Omega.log
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
	sbatch \
-D ${WorkingDirectory}/Tfms ${QueueType}\
-e "ErrTfms.log" \
-o "OutTfms.log" \
--export=SplitFolder="${WorkingDirectory}/Split",\
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
