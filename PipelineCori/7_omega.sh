#!/bin/bash

#SBATCH -N 1
#SBATCH -t 4:00:00

#module swap PrgEnv-gnu/4.6 PrgEnv-gnu/4.8
module swap PrgEnv-intel/5.2.82 PrgEnv-gnu/5.2.82

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

${PathPipeline}/0_master.sh "OmegaDone"
