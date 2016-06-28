#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard

module swap PrgEnv-pgi PrgEnv-gnu

output=${WorkingDirectory}
log=${WorkingDirectory}/assembly.log

if [ -f ${InputReads}/SingleEnd.fasta ]; then
	if [ -f ${InputReads}/PairEnd.fasta ]; then
		${PathOmega}/runOmega3.sh -inS ${InputReads}/SingleEnd.fasta \
-inP ${InputReads}/PairEnd.fasta \
-n ${NumThreads} \
-d ${output} -o ${TargetName} \
&> ${log}
	else
		${PathOmega}/runOmega3.sh -inS ${InputReads}/SingleEnd.fasta \
-n ${NumThreads} \
-d ${output} -o ${TargetName} \
&> ${log}
	fi
else 
	if [ -f ${InputReads}/PairEnd.fasta ]; then
		${PathOmega}/runOmega3.sh \
-inP ${InputReads}/PairEnd.fasta \
-n ${NumThreads} \
-d ${output} -o ${TargetName} \
&> ${log}
	fi
fi

${PathPipeline}/0_master.sh "OmegaDone"
