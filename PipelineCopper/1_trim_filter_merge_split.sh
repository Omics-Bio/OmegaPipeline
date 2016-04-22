#!/bin/bash

#PBS -l walltime=5:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard

valueInterleaved=f
if [ ${SingleRead} == "YES" ]; then
	valueInterleaved=f
else
	valueInterleaved=t
fi

if [ ${InputFile2} != "EMPTY" ]; then
	${PathBbmap}/bbduk.sh \
in=${InputFile} \
in2=${InputFile2} \
out=${WorkingDirectory}/trim.fq \
interleaved=f ftm=5 k=23 ktrim=r mink=11 hdist=1 tbo tpe qtrim=r trimq=10 minlen=70 \
ref=${PathBbmap}/resources/adapters.fa \
1>${WorkingDirectory}/trim.log \
2>&1
else
	${PathBbmap}/bbduk.sh \
in=${InputFile} \
out=${WorkingDirectory}/trim.fq \
interleaved=${valueInterleaved} ftm=5 k=23 ktrim=r mink=11 hdist=1 tbo tpe qtrim=r trimq=10 minlen=70 \
ref=${PathBbmap}/resources/adapters.fa \
1>${WorkingDirectory}/trim.log \
2>&1
fi

${PathBbmap}/bbduk.sh \
in=${WorkingDirectory}/trim.fq \
out=${WorkingDirectory}/filter.fq \
ref=${PathBbmap}/resources/phix174_ill.ref.fa.gz \
hdist=1 k=31 threads=${NumThreads} \
1>${WorkingDirectory}/filter.log 2>&1

rm ${WorkingDirectory}/trim.fq

rm ${WorkingDirectory}/trim.fq

##--------------------------
# BBmerge merge paired end reads
##--------------------------
if [ ${SingleRead} != "YES" ]; then
	${PathBbmap}/bbmerge.sh \
in=${WorkingDirectory}/filter.fq \
out=${WorkingDirectory}/merged.fq \
outu=${WorkingDirectory}/unmerged.fq \
-Xmx10G iterations=10 \
&> ${WorkingDirectory}/bbmerge.log
rm ${WorkingDirectory}/filter.fq
else
	mv ${WorkingDirectory}/filter.fq \
${WorkingDirectory}/merged.fq

fi

##--------------------------
# Split the fasta/fastq files
##--------------------------
if [ -d "${SplitFolder}" ]; then
	rm -r ${SplitFolder}
	mkdir ${SplitFolder}
	mkdir ${SplitFolder}/merged
	mkdir ${SplitFolder}/unmerged
else
	mkdir ${SplitFolder}
	mkdir ${SplitFolder}/merged
	mkdir ${SplitFolder}/unmerged
fi

if [[ -e ${WorkingDirectory}/merged.fq ]]; then
	#gunzip ${WorkingDirectory}/merged.fq.gz
	FileSizeMerged=$(du -m ${WorkingDirectory}/merged.fq | awk '{ print $1 }')
	NumFileMerged=`expr $FileSizeMerged / ${SizePerFile}`
	if [ ${NumFileMerged} \< 1 ]; then
		NumFileMerged=1
	fi
	${PathPython} ${PathPipeline}/split_rename.py \
-is ${WorkingDirectory}/merged.fq \
-o ${SplitFolder}/merged/${Filename} \
-n ${NumFileMerged} -d \
> ${WorkingDirectory}/SplitRenameMerged.log
rm ${WorkingDirectory}/merged.fq
fi

if [[ -e ${WorkingDirectory}/unmerged.fq ]]; then
	#gunzip ${WorkingDirectory}/unmerged.fq.gz
	FileSizeUnmerged=$(du -m ${WorkingDirectory}/unmerged.fq | awk '{ print $1 }')
	NumFileUnmerged=`expr $FileSizeUnmerged / ${SizePerFile}`
	if [ ${NumFileUnmerged} \< 1 ]; then
		NumFileUnmerged=1
	fi
	LastId=0
	if [[ -e ${WorkingDirectory}/SplitRenameMerged.log ]]; then
		LastId=`tail -n 1 ${WorkingDirectory}/SplitRenameMerged.log`
	fi
	${PathPython} ${PathPipeline}/split_rename.py \
-ip ${WorkingDirectory}/unmerged.fq \
-o ${SplitFolder}/unmerged/${Filename} \
-n ${NumFileUnmerged} -d -f ${LastId} \
> ${WorkingDirectory}/SplitRenameUnmerged.log
rm ${WorkingDirectory}/unmerged.fq
fi

${PathPipeline}/0_master.sh "Hero"

