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
# Pathes to the necessary programs
##################################################################
PathHero="/xxxx/software/pipelineOmega/Slehea/Slehea"
PathStorm="/xxxx/software/pipelineOmega/Storm/Storm"
PathOmega="/xxxx/software/pipelineOmega/Omega2/Omega2"
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
	cp ${WorkingDirectory}/Omega/${TargetName}_contigs.fasta ${WorkingDirectory}/
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Omega Completed." >> ${WorkingDirectory}/Omega.log
	echo "The assembled contigs is in ${WorkingDirectory}." >> ${WorkingDirectory}/Omega.log
	echo "The name is ${TargetName}_contigs.fasta" >> ${WorkingDirectory}/Omega.log
fi

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
		qsub \
-A ${Account} \
-e "${WorkingDirectory}/Omega/ErrOmega.log" \
-o "${WorkingDirectory}/Omega/OutOmega.log" \
-v PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Omega,\
InputReads=${WorkingDirectory}/Rename,\
InputAlign=${WorkingDirectory}/Align,\
PathOmega=${PathOmega},\
NumThreads=${NumThreads},\
TargetName=${TargetName},\
Filename=${Filename} \
${PathPipeline}/omega.sh \
>> ${WorkingDirectory}/Omega.log 
	fi
	exit
fi

if [ "${1}" == "RenameDone" ]
	then
	# run overlap graph construction
	NumOfSplits=`ls ${WorkingDirectory}/Rename/${Filename}*.fasta | wc -l`
	NumOfSplits=`expr ${NumOfSplits} - 1`
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Storm-Renaming Jobs." >> ${WorkingDirectory}/Omega.log
	echo "Submit Storm-Aligning Jobs..." >> ${WorkingDirectory}/Omega.log
	if [ -d "${WorkingDirectory}/Align" ]; then
		rm -r ${WorkingDirectory}/Align
		mkdir ${WorkingDirectory}/Align
	else
		mkdir ${WorkingDirectory}/Align
	fi
	qsub \
-A ${Account} \
-e "${WorkingDirectory}/Align/ErrAlign.log" \
-o "${WorkingDirectory}/Align/OutAlign.log" \
`if (( ${NumOfSplits} > 0 )); then echo "-J 0-${NumOfSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Align,\
InputPath=${WorkingDirectory}/Rename/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads},\
Filename=${Filename} \
${PathPipeline}/align.sh \
>> ${WorkingDirectory}/Omega.log 
	exit
fi

if [ "${1}" == "DedupDone" ]; then
	# check if all Dedup done or not
	NumOfSplits=`ls ${WorkingDirectory}/Merge/${Filename}*.fasta | wc -l`
	checkResults ${WorkingDirectory}/Dedup ${NumOfSplits}
	returnvalue=$?
	# rename all the reads
	if [ "${returnvalue}" == 0 ]; then
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Storm-Dedup Jobs." >> ${WorkingDirectory}/Omega.log
		echo "Submit Storm-Renaming Jobs..." >> ${WorkingDirectory}/Omega.log
		if [ -d "${WorkingDirectory}/Rename" ]; then
			rm -r ${WorkingDirectory}/Rename
			mkdir ${WorkingDirectory}/Rename
		else
			mkdir ${WorkingDirectory}/Rename
		fi
	qsub \
-A ${Account} \
-e "${WorkingDirectory}/Rename/ErrRename.log" \
-o "${WorkingDirectory}/Rename/OutRename.log" \
-v PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Rename,\
InputPath=${WorkingDirectory}/Dedup/,\
Filename=${Filename},\
NumOfSplits=${NumOfSplits} \
${PathPipeline}/rename.sh \
>> ${WorkingDirectory}/Omega.log 
	fi
	exit
fi

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
	qsub \
-A ${Account} \
-e "${WorkingDirectory}/Dedup/ErrDedup.log" \
-o "${WorkingDirectory}/Dedup/OutDedup.log" \
`if (( ${NumOfSplits} > 0 )); then echo "-J 0-${NumOfSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Dedup,\
InputPath=${WorkingDirectory}/Merge,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads},\
Filename=${Filename} \
${PathPipeline}/dedup.sh \
>> ${WorkingDirectory}/Omega.log 
	exit
fi

if [ "${1}" == "MergeDone" ]; then
	#rename the results from STORM_merge
	numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
	checkResults ${WorkingDirectory}/Merge/ ${numOfUnmergedSplits}
	returnvalue=$?

	if [ "${returnvalue}" == 0 ]; then
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Merging Jobs." >> ${WorkingDirectory}/Omega.log
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
			mv ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newId}.fasta
		done
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
		${PathPipeline}/master.sh "HeroDone"
		exit
	fi
fi

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
			qsub \
-A ${Account} \
-e "${WorkingDirectory}/Merge/ErrMerge.log" \
-o "${WorkingDirectory}/Merge/OutMerge.log" \
`if (( ${numOfUnmergedSplits} > 0 )); then echo "-J 0-${numOfUnmergedSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v SplitFolderMerged=${WorkingDirectory}/Hero/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Hero/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Hero/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Merge/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads} \
${PathPipeline}/storm.sh \
>> ${WorkingDirectory}/Omega.log
		else
			#move to Merge and rename
			numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
			for(( i=0; i<${numOfUnmergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				mv ${WorkingDirectory}/Hero/unmerged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
			done
			numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
			for(( i=0; i<${numOfMergedSplits}; i++ )); do
				newname=`printf "%02d" ${i}`
				newId=`expr ${numOfUnmergedSplits} + ${i}`
				newId=`printf "%02d" ${newId}`
				mv ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newId}.fasta
			done
			echo Time is $(date) >> ${WorkingDirectory}/Omega.log
			echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
			${PathPipeline}/master.sh "HeroDone"
		fi
	elif (( ${countMerged}>0 )); then
		numOfMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
		for(( i=0; i<${numOfMergedSplits}; i++ )); do
			newname=`printf "%02d" ${i}`
			mv ${WorkingDirectory}/Hero/merged/${Filename}_${newname}.fasta \
${WorkingDirectory}/Merge/${Filename}_${newname}.fasta
		done
		echo Time is $(date) >> ${WorkingDirectory}/Omega.log
		echo "Finish Moving Jobs." >> ${WorkingDirectory}/Omega.log
		${PathPipeline}/master.sh "HeroDone"
	elif (( ${countUnmerged}>0 )); then
		numOfUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
		numOfUnmergedSplits=`expr ${numOfUnmergedSplits} - 1`
		qsub \
-A ${Account} \
-e "${WorkingDirectory}/Merge/ErrMerge.log" \
-o "${WorkingDirectory}/Merge/OutMerge.log" \
`if (( ${numOfUnmergedSplits} > 0 )); then echo "-J 0-${numOfUnmergedSplits}:1"; else echo "-v PBS_ARRAY_INDEX=0"; fi` \
-v SplitFolderMerged=${WorkingDirectory}/Hero/merged,\
SplitFolderUnmerged=${WorkingDirectory}/Hero/unmerged,\
Filename=${Filename},\
Target=${WorkingDirectory}/Hero/unmerged,\
PathPipeline=${PathPipeline},\
WorkingDirectory=${WorkingDirectory}/Merge/,\
PathStorm=${PathStorm},\
NumThreads=${NumThreads} \
${PathPipeline}/storm.sh \
>> ${WorkingDirectory}/Omega.log
	fi
	exit
fi

if [ "${1}" == "Hero" ]
	then
	# run Heterogeneity remover
	echo Time is $(date) >> ${WorkingDirectory}/Omega.log
	echo "Finish Triming, Filtering, Merging, and Spliting Jobs..." >> ${WorkingDirectory}/Omega.log
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
		${PathPipeline}/master.sh Merge
		exit
	fi

	# first run Hero on merged reads
	if(( ${numOfMergedSplits} > 0 )); then
		#echo "Number of merged splits: " ${numOfMergedSplits}
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
Mismatch=${Mismatch},\
NumThreads=${NumThreads},\
MinOverlapLength=${MinOverlapLength} \
${PathPipeline}/hero.sh \
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
${PathPipeline}/hero.sh \
>> ${WorkingDirectory}/Omega.log
	fi
	exit
fi

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
	#sed -i "s#^PathPipeline.*#PathPipeline=${WorkingDirectory}/Scripts/#1" ${WorkingDirectory}/Scripts/master.sh
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
PathSga="${PathSga}",\
ErrorCorrection="${ErrorCorrection}",\
SingleRead="${SingleRead}",\
WorkingDirectory="${WorkingDirectory}/Tfms",\
NumThreads="${NumThreads}" \
${PathPipeline}/trim_merge.sh \
>> ${WorkingDirectory}/Omega.log
	exit
	innerNumMergedSplits=`ls ${WorkingDirectory}/Split/merged | wc -l`
	innerNumUnmergedSplits=`ls ${WorkingDirectory}/Split/unmerged | wc -l`
	sed -i "0,/^innerNumMergedSplits.*/s//innerNumMergedSplits=${innerNumMergedSplits}/" ${PathPipeline}/master.sh
	sed -i "0,/^innerNumUnmergedSplits.*/s//innerNumUnmergedSplits=${innerNumUnmergedSplits}/" ${PathPipeline}/master.sh
	exit
fi
