#!/bin/env bash

nCores=6
threadsPerCore=2
nThreads=$((nCores * threadsPerCore))
binName=./CNS2d.gnu.MPI.ex
#binName=./CNS2d.gnu.DEBUG.MPI.ex
visitFile=plot.visit

rm -rfv ./output

make -j ${nThreads} && OMP_NUM_THREADS=1 mpiexec -n ${nCores} ${binName} inputs $@ && rm -vf plot.visit

for dir in $(ls -1v --color=never ./output | sed '/.*\(old\)/d')
do
	echo "./output/${dir}/Header" >> ${visitFile}
done
