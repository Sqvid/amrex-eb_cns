
#include "AMReX_Array.H"
#include "AMReX_EB2_GeometryShop.H"
#include "AMReX_EB2_IF_Box.H"
#include "AMReX_EB2_IF_Intersection.H"
#include "AMReX_EB2_IF_Plane.H"
#include "AMReX_EB2_IF_Rotation.H"
#include "AMReX_EB2_IF_Sphere.H"
#include "AMReX_SPACE.H"
#include <AMReX_EB2.H>
#include <AMReX_EB2_IF.H>

#include <AMReX_ParmParse.H>

#include <cmath>
#include <algorithm>

using namespace amrex;

constexpr Real PI = 3.14159265358979;

void
initialize_EB2 (const Geometry& geom, const int /*required_coarsening_level*/,
                const int max_coarsening_level)
{
    BL_PROFILE("initializeEB2");

    ParmParse ppeb2("eb2");
    std::string geom_type;
    ppeb2.get("geom_type", geom_type);

    if (geom_type == "schardin") {
        RealArray triangleTip({0.1, 0.1});
        RealArray llCorner({0.1, 0.09});
        RealArray urCorner({0.1 + 0.02 * std::cos(30.0 * PI / 180.0), 0.11});

        RealArray upperNorm, lowerNorm;
        upperNorm[0] = std::cos(60.0 * PI / 180.0);
        upperNorm[1] = -std::sin(60.0 * PI / 180.0);
        lowerNorm[0] = upperNorm[0];
        lowerNorm[1] = -upperNorm[1];

        EB2::BoxIF box(llCorner, urCorner, false);
        EB2::PlaneIF upperSlope(triangleTip, upperNorm);
        EB2::PlaneIF lowerSlope(triangleTip, lowerNorm);

        auto finalShape = EB2::makeIntersection(box, upperSlope, lowerSlope);

        auto gshop = EB2::makeShop(finalShape);
        EB2::Build(gshop, geom, max_coarsening_level, max_coarsening_level, 4);
    } else if (geom_type == "pipe") {
        auto W = 0.0141;

        EB2::PlaneIF upperSlope(RealArray({0.1,0.1 + W}), RealArray({0, 1}));
        EB2::PlaneIF lowerSlope(RealArray({0.1,0.1 - W}), RealArray({0, -1}));

        auto finalShape = EB2::makeUnion(upperSlope, lowerSlope);

        auto gshop = EB2::makeShop(finalShape);
        EB2::Build(gshop, geom, max_coarsening_level, max_coarsening_level, 4);
    } else {
        EB2::Build(geom, max_coarsening_level, max_coarsening_level, 4);
    }
}
