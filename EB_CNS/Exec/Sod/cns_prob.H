#ifndef CNS_PROB_H_
#define CNS_PROB_H_

#include <AMReX_Geometry.H>
#include <AMReX_FArrayBox.H>
#include <cmath>
#include "AMReX_Print.H"
#include "AMReX_REAL.H"
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

	Real w = 0.0141;
	//const Real pi = 3.141592654;
	//Real theta = (30 * pi) / 180;
	//Real theta = 0.3;
	Real theta = 0;

    const Real* prob_lo = geomdata.ProbLo();
    const Real* dx      = geomdata.CellSize();

    Real x = prob_lo[0] + (i+Real(0.5))*dx[0];
    Real y = prob_lo[1] + (j+Real(0.5))*dx[1];

	Real xRot {}, yRot {}, xFulc {0}, yFulc {0};
	xRot = (x - xFulc)*std::cos(theta) + (y - yFulc)*std::sin(theta);
	yRot = -(x - xFulc)*std::sin(theta) + (y - yFulc)*std::cos(theta);

    Real Pt, rhot, uxt, uyt;
	Pt = prob_parm.p_r;
	Real v = prob_parm.u_r;
	Real rho0 = 1.225, d = 0.08;// + v*0.0008;

	Real g {};
	Real centre = 0.1;
	Real p = y - centre - x*std::tan(theta);
	Real b = w / std::cos(theta);

	if (p > -b - dx[0] && p < b + dx[0]) {
		g = (xRot - d) / (Real(0.5) * w);
		rhot = rho0 + std::exp(-g*g);
	} else {
		rhot = rho0;
	}

	uxt = v * std::cos(theta);
	uyt = v * std::sin(theta);

    state(i,j,k,URHO) = rhot;
    state(i,j,k,UMX) = rhot*uxt;
    state(i,j,k,UMY) = rhot*uyt;
#if (AMREX_SPACEDIM == 3)
    state(i,j,k,UMZ) = Real(0.0);
#endif
    Real et = Pt/(parm.eos_gamma-Real(1.0));
    state(i,j,k,UEINT) = et;
    state(i,j,k,UEDEN) = et + Real(0.5)*rhot*(uxt*uxt + uyt*uyt);
    state(i,j,k,UTEMP) = Real(0.0);
}

#endif
