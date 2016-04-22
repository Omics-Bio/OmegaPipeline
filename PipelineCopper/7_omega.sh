#!/bin/bash

#PBS -l walltime=6:00:00
#PBS -l select=1:ncpus=32:mpiprocs=1
#PBS -q standard

module swap PrgEnv-pgi/5.2.82 PrgEnv-gnu/5.2.82

fastqs=(${InputReads}/${Filename}_[0-9]*.fasta)
reads=$(echo ${fastqs[@]} | tr " " ",")
align_out=(${InputAlign}/${Filename}_[0-9]*.align)
edge=$(echo ${align_out[@]} | tr " " ",")

ovl=50
output=${WorkingDirectory}
log=${WorkingDirectory}/assembly.log

${PathOmega} -f ${reads} -e ${edge} \
-mld 1000 -mcf 10 -mlr 200 -ovl ${ovl} \
-o ${output}/${TargetName} -log DEBUG \
&> ${log}

${PathPipeline}/master.sh "OmegaDone"
