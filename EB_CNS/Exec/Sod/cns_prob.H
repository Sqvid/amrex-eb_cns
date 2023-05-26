#ifndef CNS_PROB_H_
#define CNS_PROB_H_

#include <AMReX_Geometry.H>
#include <AMReX_FArrayBox.H>
#include <cmath>
#include "AMReX_Print.H"
#include "CNS_index_macros.H"
#include "CNS_parm.H"
#include "cns_prob_parm.H"

AMREX_GPU_DEVICE
inline
void
cns_initdata (int i, int j, int k, amrex::Array4<amrex::Real> const& state,
              amrex::GeometryData const& geomdata, Parm const& parm, ProbParm const& prob_parm)
{
    using amrex::Real;

    const Real* prob_lo = geomdata.ProbLo();
    const Real* dx      = geomdata.CellSize();

    Real x = prob_lo[0] + (i+Real(0.5))*dx[0];
    Real y = prob_lo[1] + (j+Real(0.5))*dx[1];

	//amrex::PrintToFile yFile("yVals");
	//yFile << prob_lo[1] << " " << j << " " << dx[1] << " " << y << "\n";

    Real Pt, rhot, uxt;
    //if (x < Real(0.1)) {
    //    Pt = prob_parm.p_l;
    //    rhot = prob_parm.rho_l;
    //    uxt = prob_parm.u_l;
    //} else {
    //    Pt = prob_parm.p_r;
    //    rhot = prob_parm.rho_r;
    //    uxt = prob_parm.u_r;
    //}
	double w = 0.0141, halfW = w / 2;
	//if ((y > (0.1 - halfW)) && (y < (0.1 + halfW))) {
	Pt = prob_parm.p_r;
	double rho0 = 1.225;
	double c = 0.05;
	rhot = rho0 + std::exp(-((x - c) / (0.5 * w)) * ((x - c) / (0.5 * w)));
	uxt = prob_parm.u_r;
	//} else {
	//	Pt = 0;
	//	rhot = 0;
	//	uxt = 0;
	//}

    state(i,j,k,URHO ) = rhot;
    state(i,j,k,UMX  ) = rhot*uxt;
    state(i,j,k,UMY  ) = Real(0.0);
#if (AMREX_SPACEDIM == 3)
    state(i,j,k,UMZ  ) = Real(0.0);
#endif
    Real et = Pt/(parm.eos_gamma-Real(1.0));
    state(i,j,k,UEINT) = et;
    state(i,j,k,UEDEN) = et + Real(0.5)*rhot*uxt*uxt;
    state(i,j,k,UTEMP) = Real(0.0);
}

#endif
