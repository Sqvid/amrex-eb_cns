#!/bin/env bash

export PATH=$(echo $PATH | sed s/cuda-11.2/cuda-12.1/g)

# Parallelisation parameters.
nCores=32
dim=2
makeFlags="-j ${nCores} DIM=${dim}"

mpiBin=./CNS${dim}d.gnu.MPI.ex
mpiOmpBin=./CNS${dim}d.gnu.MPI.OMP.ex
ompBin=./CNS${dim}d.gnu.OMP.ex
mpiCudaBin=./CNS${dim}d.gnu.MPI.CUDA.ex

mpiTest="USE_MPI=TRUE"
mpiOmpTest="${mpiTest} USE_OMP=TRUE"
ompTest="USE_MPI=FALSE USE_OMP=TRUE"
mpiCudaTest="${mpiTest} USE_CUDA=TRUE"

nRuns=1

#refRatio="2 2 2 2"
#amrMaxLevel=0
#amrMaxLevel=$(echo ${refRatio} | wc -w)
#echo "${amrMaxLevel} LEVELS"
blockingFactor=8
#maxGridSize=128
gridEff=0.8
refineDengrad=0.005

runTimeTest() {
	testname=${1}
	res=${2}

	# Tests are repeated for different resolutions multiple times.
	for run in $(seq ${nRuns}); do
		case ${testname} in
			${mpiTest})
				outfile=time_MPI_${nCores}_${res}
				mpiProcs=${nCores}
				bin=${mpiBin}
				;;

			${mpiOmpTest})
				bin=${mpiOmpBin}
				mpiExtraOpts="--bind-to numa"
				mpiProcs=16
				ompThreads=2
				export OMP_NUM_THREADS=${ompThreads}
				export OMP_WAIT_POLICY=active
				export OMP_PROC_BIND=false
				export OMP_DISPLAY_ENV=true
				outfile=time_MPI_${mpiProcs}_OMP_${ompThreads}_${res}
				#outfile=time_OMP_${ompThreads}_${res}
				;;

			${ompTest})
				bin=${ompBin}
				ompThreads=32
				export OMP_NUM_THREADS=${ompThreads}
				export OMP_WAIT_POLICY=active
				export OMP_PROC_BIND=false
				export OMP_DISPLAY_ENV=true
				outfile=time_OMP_${ompThreads}_${res}
				;;

			${mpiCudaTest})
				mpiProcs=2
				outfile=time_MPI_${mpiProcs}_CUDA_${res}
				bin=${mpiCudaBin}
				makeFlags="${makeFlags} CUDA_ARCH=8.0"
				;;
			*)
				echo "UNRECOGNISED TESTNAME"
				exit 1
				;;
		esac

		if [ ${amrMaxLevel} -gt 0 ]; then
			outfile=${outfile}_AMR_$(echo ${refRatio} | sed 's/ /-/g')_BF-${blockingFactor}
		fi

		outfile=${outfile}_${run}

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

		if [ "${bin}" != "${ompBin}" ]; then
			bin="mpiexec -n ${mpiProcs} ${mpiExtraOpts} ${bin}"
		fi

		echo "BLOCKING FACTOR: ${blockingFactor}"

		${bin} inputs \
			eb2.geom_type= schardin \
			max_step="-1" stop_time="0.0002" \
			eb2.build_coarse_level_by_coarsening="false" \
			cns.do_visc="false" cns.eb_weights_type=3 \
			prob.p_l=96400 prob.p_r=50000 \
			prob.rho_l=0.944 prob.rho_r=0.595 \
			prob.u_l=169.68 prob.u_r=0.0 \
			cns.cfl=0.5 \
			amr.n_cell="${res} ${res} ${res}" amr.v=0 cns.v=0 \
			amr.plot_files_output=0 \
			amr.max_level=${amrMaxLevel} cns.refine_max_dengrad_lev=${amrMaxLevel} \
			cns.refine_dengrad=${refineDengrad} \
			amr.blocking_factor=${blockingFactor} \
			amr.max_grid_size=${maxGridSize} \
			amr.ref_ratio=${refRatio} \
			amr.grid_eff=${gridEff} \
			> ${outfile} 2>&1

		if [ "${?}" != "0" ]; then
			echo "Simulation error. Fix this."
			mv "${outfile}" "${outfile}_BROKEN"
			exit 1
		fi

	done
}

if [ "${#}" == "0" ]; then
	#for testname in "${mpiCudaTest}"; do
	#for testname in "${mpiOmpTest}"; do
	#for res in 64; do
		res=64
		refRatio="2 2 2 2"
		amrMaxLevel=$(echo ${refRatio} | wc -w)
		blockingFactor=8
		maxGridSize=128
		steps=$(((maxGridSize / blockingFactor) - 1))
		#for testname in "${mpiCudaTest}"; do
		#for testname in "${mpiTest}" "${ompTest}" "${mpiOmpTest}" ; do
		for testname in "${mpiTest}"; do
			bf=4

			while [ ${bf} -le $((res / 2)) ]; do
				bf=$((bf * 2))
				blockingFactor=${bf} runTimeTest "${testname}" ${res}
			done
		done
	#done

elif [ "${1}" == "clean" ]; then
	make clean
	rm -vf time_MPI_*
fi
