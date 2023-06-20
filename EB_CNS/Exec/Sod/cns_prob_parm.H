#ifndef CNS_PROB_PARM_H_
#define CNS_PROB_PARM_H_

#include <AMReX_REAL.H>
#include <AMReX_GpuMemory.H>

using namespace amrex::literals;

struct ProbParm
{
    amrex::Real p_l {};
    amrex::Real p_r {};
    amrex::Real rho_l {};
    amrex::Real rho_r {};
    amrex::Real u_l {};
    amrex::Real u_r {};
};

#endif
