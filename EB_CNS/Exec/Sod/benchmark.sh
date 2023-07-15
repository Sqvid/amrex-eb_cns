#!/bin/env bash

# Parallelisation parameters.
nCores=6
threadsPerCore=2
nThreads=$((nCores * threadsPerCore))
makeFlags="-j ${nCores} DIM=2"

mpiBin=./CNS2d.gnu.MPI.ex
mpiOmpBin=./CNS2d.gnu.MPI.OMP.ex
mpiCudaBin=./CNS2d.gnu.MPI.CUDA.ex

mpiTest="USE_MPI=TRUE"
mpiOmpTest="${mpiTest} USE_OMP=TRUE"
mpiCudaTest="${mpiTest} USE_CUDA=TRUE"

amrMaxLevel=2
blockingFactor=8
maxGridSize=128
refineDengrad=0.02

runTimeTest() {
	testname=${1}
	#resolutions="64 128 256 512 1024 2048 4096"
	resolutions="128 256 512"

	# Tests are repeated for different resolutions multiple times.
	for res in ${resolutions}; do
		for run in {1..3}; do
			case ${testname} in
				${mpiTest})
					outfile=time_MPI_${res}_${run}
					mpiProcs=${nCores}
					bin=${mpiBin}
					;;

				${mpiOmpTest})
					bin=${mpiOmpBin}
					mpiExtraOpts="--bind-to numa"
					mpiProcs=3
					ompThreads=2
					export OMP_NUM_THREADS=${ompThreads}
					export OMP_WAIT_POLICY=active
					export OMP_DISPLAY_ENV=true
					outfile=time_MPI_${mpiProcs}_OMP_${ompThreads}_${res}_${run}
					;;

				${mpiCudaTest})
					outfile=time_MPI_CUDA_${res}_${run}
					mpiProcs=2
					bin=${mpiCudaBin}
					makeFlags="${makeFlags} CUDA_ARCH=8.0"
					;;
				*)
					echo "UNRECOGNISED TESTNAME"
					exit 1
					;;
			esac

			make ${makeFlags} ${testname}

			if [ ${?} -ne 0 ]; then
				echo "Build for ${testname} failed."
				exit 1
			fi

			if [ -f "$outfile" ]; then
				echo "Time test result exists for ${testname}, ${res}x${res}, run ${run}."
				echo "Skipping..."
				continue
			fi

			echo "" | tee ${outfile}
			echo "${testname}: ${res}x${res}, RUN: ${run}" | tee ${outfile}
			echo "------------------------------------------------------" | tee ${outfile}
			echo ""
			echo "******************************************************"
			echo "Starting test at $(date)"
			echo "******************************************************"
			echo ""

			#echo OMP_NUM_THREADS=${ompThreads} mpiexec ${mpiExtraOpts} -n ${mpiProcs} ${bin} inputs \
			#	amr.n_cell="${res} ${res}" amr.v=0 cns.v=0

			mpiexec -n ${mpiProcs} ${mpiExtraOpts} ${bin} inputs \
				amr.n_cell="${res} ${res}" amr.v=0 cns.v=0 \
				amr.max_level=${amrMaxLevel} cns.refine_max_dengrad_lev=${amrMaxLevel} \
				cns.refine_dengrad=${refineDengrad} \
				amr.blocking_factor=${blockingFactor} \
				amr.max_grid_size=${maxGridSize} \
				> ${outfile} 2>&1

			if [ "${?}" != "0" ]; then
				echo "Simulation error. Fix this."
				mv "${outfile}" "${outfile}_BROKEN"
				exit 1
			fi

			done
		done
}

if [ "${#}" == "0" ]; then
	#for testname in "${mpiTest}" "${mpiOmpTest}" "${mpiCudaTest}"; do
	#for testname in "${mpiOmpTest}"; do
	for testname in "${mpiTest}" "${mpiOmpTest}"; do
		runTimeTest "${testname}"
	done

elif [ "${1}" == "clean" ]; then
	make clean
	rm -vf time_MPI_*
fi
