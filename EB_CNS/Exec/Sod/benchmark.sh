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
mpiOmpTest="USE_MPI=TRUE USE_OMP=TRUE"
ompTest="USE_MPI=FALSE USE_OMP=TRUE"
cuda1Test="USE_MPI=TRUE USE_CUDA=TRUE"
cuda2Test="${cuda1Test} IGNORETHISVAR=FOO"

nRuns=3

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
                                mpiProcs=${nCores}
                                outfile=time_MPI-${mpiProcs}_${res}
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
                                outfile=time_MPI-${mpiProcs}_OMP-${ompThreads}_${res}
                                #outfile=time_OMP_${ompThreads}_${res}
                                ;;

                        ${ompTest})
                                bin=${ompBin}
                                ompThreads=32
                                export OMP_NUM_THREADS=${ompThreads}
                                export OMP_WAIT_POLICY=active
                                export OMP_PROC_BIND=false
                                export OMP_DISPLAY_ENV=true
                                outfile=time_OMP-${ompThreads}_${res}
                                ;;

                        ${cuda1Test})
                                mpiProcs=1
                                outfile=time_CUDA-${mpiProcs}_${res}
                                bin=${mpiCudaBin}
                                makeFlags="${makeFlags} CUDA_ARCH=8.0"
                                ;;

                        ${cuda2Test})
                                mpiProcs=2
                                outfile=time_CUDA-${mpiProcs}_${res}
                                bin=${mpiCudaBin}
                                makeFlags="${makeFlags} CUDA_ARCH=8.0"
                                ;;
                        *)
                                echo "UNRECOGNISED TESTNAME"
                                exit 1
                                ;;
                esac

                if [ ${amrMaxLevel} -gt 0 ]; then
                        outfile=${outfile}_${amrMaxLevel}Lev
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
        for res in 64 128; do
        #for res in 64 128 256 512 1024 2048 4096; do
		echo ${res}
                effective=${res}
                refRatio="2"
                amrMaxLevel=$(printf %.0f $(echo "l(${effective}/${res})/l(2)" | bc -l))
                echo "${amrMaxLevel} LEVELS"
                blockingFactor=8
                maxGridSize=128

                #for testname in "${mpiTest}"; do
                #for testname in "${mpiTest}" "${ompTest}"; do
                for testname in "${mpiTest}" "${ompTest}" "${mpiOmpTest}" "${cuda1Test}" "${cuda2Test}"; do
                        runTimeTest "${testname}" ${res}
                done
        done

elif [ "${1}" == "clean" ]; then
        rm -vf time_MPI*
        rm -vf time_OMP*
        rm -vf time_CUDA*
fi
