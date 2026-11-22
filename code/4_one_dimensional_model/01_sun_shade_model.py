"""One-dimensional sun-shade model of canopy photosynthesis for every Helios plot-date

Purpose
    Computes canopy net photosynthesis (canopy A) of each of the 5,299 plot-dates simulated
    with Helios, with a one-dimensional sun-shade two-leaf model (de Pury & Farquhar, 1997)
    that shares the leaf physiology of the Helios runs. The canopy has ten layers of equal
    LAI with sunlit and shaded leaves in each. Incident PAR is split into direct and diffuse
    light as in Spitters et al. (1986), and the PAR and NIR absorbed by sunlit and shaded
    leaves follow the two-stream equations of de Pury & Farquhar (1997) for a planophile
    leaf-angle distribution. Leaf temperature and intercellular CO2 of each leaf class come
    from the leaf energy balance, the Buckley-Mott-Farquhar stomatal model and the Pohlhausen
    boundary-layer conductance of Helios, with the Helios coefficients. Leaf biochemistry
    (Vcmax25 and its canopy profile, Jmax25, Rd25, Tp25 and the FvCB constants) is that of the
    Helios runs. The two models therefore differ mainly in radiation transport, and the
    narrow-minus-broad difference that Helios predicts beyond the 1D model is the
    architectural residual (Methods S1.6). The default run gives Fig 4, Table S16 and the 1D
    side of Table S19. Two sensitivity runs change one modeling choice each (Run settings
    below) and are compared by 02_sensitivity_longwave_nir.R (Methods S1.6).

Run settings (environment variables)
    CFG_LW_OFF=1      net longwave exchange of leaves set to zero (default 0)
    CFG_NIR_SLRFD=0   incident NIR set equal to incident PAR instead of station shortwave
                      minus PAR (default 1)
    CFG_TAG=<suffix>  suffix added to the output file names (default none)
    The paper uses three runs:
      default settings                         helios_vs_1D_per_plot.csv
      CFG_LW_OFF=1    CFG_TAG=_longwave_off    helios_vs_1D_per_plot_longwave_off.csv
      CFG_NIR_SLRFD=0 CFG_TAG=_nir_equals_par  helios_vs_1D_per_plot_nir_equals_par.csv

Inputs
    outputs/helios/helios_canopy_summary_EF.csv   Helios canopy A and run inputs per plot-date,
    outputs/helios/helios_canopy_summary_SF.csv   by site (04_combine_task_outputs.py)
    data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   per-plot inputs of the
    data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   Helios runs (Rd25, Tp25,
        wind speed, pressure, station shortwave, leaf optics and leaflet size)

Outputs
    outputs/one_dimensional_model/helios_vs_1D_per_plot<CFG_TAG>.csv   per plot-date: Helios
        and 1D canopy A, sunlit and shaded leaf temperatures of the 1D model, and the
        difference Helios minus 1D (absolute and in percent of Helios)
    outputs/one_dimensional_model/helios_vs_1D_summary<CFG_TAG>.txt   Pearson r, RMSE and mean
        difference of the two models, and the mean difference per site, row spacing and
        leaflet type

Usage (from the package root)
    python code/4_one_dimensional_model/01_sun_shade_model.py
    CFG_LW_OFF=1 CFG_TAG=_longwave_off python code/4_one_dimensional_model/01_sun_shade_model.py
    CFG_NIR_SLRFD=0 CFG_TAG=_nir_equals_par python code/4_one_dimensional_model/01_sun_shade_model.py

Requirements
    Python 3 (3.12 used); numpy 2 or later (numpy.trapezoid), pandas, scipy
"""
import os
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime
from scipy.optimize import brentq

# ----------------------------------------------------------------------------
# Modeling choices that Helios does not define for a one-dimensional canopy (Methods S1.6)
# ----------------------------------------------------------------------------
# Ratio of the boundary-layer conductance to water vapor and to heat. The Helios energy
# balance converts the heat conductance to a vapor conductance with the factor 1.08, and the
# same factor is used here for the leaf-surface vapor balance of the stomatal model.
GBW_OVER_GH = 1.08

# Leaf characteristic length L of the Pohlhausen conductance, gH = 0.135 sqrt(U/L) Nsides.
# Helios builds each leaflet as one tile object (length_m x avwidth_m, divided into 3 x 3
# elements) and, with no object_length set, takes L as the square root of the area of the
# whole leaflet. The factor 1 therefore gives L = sqrt(length_m x avwidth_m).
LEAF_SUBDIV_FACTOR = 1.0

# Longwave exchange. Each leaf exchanges longwave radiation with surroundings at air
# temperature, so that net longwave = Nsides x emissivity x sigma x (Ta^4 - Tleaf^4).
# CFG_LW_OFF=1 sets net longwave to zero (sensitivity run). CFG_TAG is the suffix of the
# output file names.
LW_ENV_AT_AIR_T = True
LW_OFF = os.environ.get("CFG_LW_OFF", "0") == "1"
RUN_TAG = os.environ.get("CFG_TAG", "")

# Incident NIR above the canopy. Helios computes NIR with its clear-sky solar model, which is
# not available here. NIR is taken as station broadband shortwave (SlrFD, kW m-2) minus PAR,
# with UV neglected. CFG_NIR_SLRFD=0 sets NIR equal to PAR instead (sensitivity run).
USE_SLRFD_FOR_NIR = os.environ.get("CFG_NIR_SLRFD", "1") == "1"

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------
ROOT         = Path(os.environ.get("PACKAGE_ROOT", "."))
HELIOS_OUT   = ROOT / "outputs" / "helios"
INPUTS_DIR   = ROOT / "data" / "simulation_inputs"
OUT          = ROOT / "outputs" / "one_dimensional_model"
OUT.mkdir(parents=True, exist_ok=True)

# Row spacing codes of the data (inches) and the row spacing they stand for.
ROW_SPACING_CM = {15: "38 cm", 30: "76 cm"}

# ----------------------------------------------------------------------------
# Leaf photosynthesis (FvCB) parameters, as in the Helios runs
# ----------------------------------------------------------------------------
KC25, KO25, GAMMASTAR25 = 404.9, 278.4, 42.75      # Kc (umol mol-1), Ko (mmol mol-1) and Gamma* (umol mol-1) at 25 C (Bernacchi et al., 2001, Table 1)
EA_KC, EA_KO, EA_GS     = 79430.0, 36380.0, 37830.0  # activation energies of Kc, Ko and Gamma*, J mol-1 (Bernacchi et al., 2001)
EA_VCMAX, EA_JMAX, EA_RD = 65330.0, 43900.0, 46390.0  # activation energies of Vcmax and Rd (Bernacchi et al., 2001) and Jmax (Sharkey et al., 2007), J mol-1
ALPHA, THETA, O2        = 0.385, 0.70, 210          # quantum efficiency and curvature of electron transport, as in the Helios runs. O2 in mmol mol-1.
SIGMA_PAR               = 0.15                       # leaf scattering coefficient of PAR (de Pury & Farquhar, 1997, Table 2)
R_GAS, T_REF, LATITUDE  = 8.314, 298.15, 40.07       # gas constant (J mol-1 K-1), reference temperature (K), latitude for the solar zenith angle (degrees N)
PAR_W_TO_UMOL           = 4.6                         # umol photons per J of PAR (Thimijan & Heins, 1983)
K_N                     = 0.64                        # coefficient of the Vcmax25 profile (Wang et al., 2026)
N_LAYERS                = 10                          # canopy layers of equal LAI
CA_DEFAULT              = 415.0                       # ambient CO2, ppm (each row uses the CO2 of its Helios run)

# ----------------------------------------------------------------------------
# Energy balance and stomatal constants of Helios
# ----------------------------------------------------------------------------
CP_AIR_MOL  = 29.25      # heat capacity of air, J mol-1 K-1 (EnergyBalanceModel.h)
LAMBDA_MOL  = 44000.0    # latent heat of vaporization, J mol-1 (EnergyBalanceModel.h, at 300 K)
SIGMA_SB    = 5.67e-8    # Stefan-Boltzmann constant, W m-2 K-4
EPS_LEAF    = 0.95       # leaf emissivity (EMISS_LW in helios_main.cpp)
PAR_W_TO_UMOL_HELIOS = 4.57   # conversion of absorbed PAR in the Helios stomatal model, umol J-1
SURFACE_HUMIDITY = 1.0   # relative humidity at the evaporating surface (Helios default)
STOMATAL_SIDEDNESS = 0.0 # stomata on one leaf face (Helios default)
NSIDES = 2               # leaves exchange heat and radiation on both faces (Helios default)

# Buckley-Mott-Farquhar coefficients (Helios defaults, StomatalConductanceModel.h)
BMF_Em, BMF_i0, BMF_k, BMF_b = 258.25, 38.65, 232916.82, 609.67
BMF_BETA = 1.0           # soil moisture stress factor (no stress)


# ============================================================
# Leaf-level functions
# ============================================================
def arrhenius(value25, Ea, T_K):
    """Arrhenius temperature response of a parameter with value value25 at 25 C."""
    return value25 * np.exp((Ea / (R_GAS * T_REF)) * (1.0 - T_REF / T_K))


def esat_Pa(T_K):
    """Saturation vapor pressure (Pa). Helios EnergyBalanceModel.h, Campbell & Norman 3.8."""
    Tc = T_K - 273.15
    return 611.0 * np.exp(17.502 * Tc / (Tc + 240.97))


def fvcb_A_at(PAR_umol, Vcmax25, Jmax25, Rd25, Tp25, T_K, Ci):
    """Net leaf photosynthesis (umol m-2 s-1) at leaf temperature T_K and intercellular CO2 Ci.

    Rd, Vcmax, Jmax, Kc, Ko and Gamma* follow Arrhenius temperature responses. Tp does not
    depend on temperature, as in the Helios runs. Electron transport J is the non-rectangular
    hyperbola of absorbed PAR, and net photosynthesis is the smallest of the Rubisco-limited,
    electron-transport-limited and triose-phosphate-limited rates minus Rd.
    """
    Rd = arrhenius(Rd25, EA_RD, T_K)
    if PAR_umol <= 0:
        return -Rd
    Vcmax = arrhenius(Vcmax25, EA_VCMAX, T_K)
    Jmax  = arrhenius(Jmax25,  EA_JMAX,  T_K)
    Kc    = arrhenius(KC25,    EA_KC,    T_K)
    Ko    = arrhenius(KO25,    EA_KO,    T_K)
    Gs    = arrhenius(GAMMASTAR25, EA_GS, T_K)
    a, b, c = THETA, -(ALPHA * PAR_umol + Jmax), ALPHA * PAR_umol * Jmax
    J = (-b - np.sqrt(max(b * b - 4 * a * c, 0.0))) / (2.0 * a)
    Km = Kc * (1.0 + O2 / Ko)
    Ac = Vcmax * (Ci - Gs) / (Ci + Km)
    Aj = J * (Ci - Gs) / (4.0 * (Ci + 2.0 * Gs))
    Ap = 3.0 * Tp25
    return min(Ac, Aj, Ap) - Rd


# ============================================================
# Light: sun position, direct and diffuse PAR, and sun-shade absorbed irradiance
# ============================================================
def solar_zenith_rad(DOY, latitude_deg=LATITUDE, hour_angle_deg=0.0):
    """Solar zenith angle (radians) on day of year DOY at the given hour angle (0 = solar noon)."""
    decl_deg = 23.45 * np.sin(np.deg2rad(360.0 * (284 + DOY) / 365.0))
    decl, lat, h = map(np.deg2rad, (decl_deg, latitude_deg, hour_angle_deg))
    cos_z = np.sin(lat) * np.sin(decl) + np.cos(lat) * np.cos(decl) * np.cos(h)
    return float(np.arccos(max(cos_z, 0.01)))


def spitters_direct_diffuse(PAR_above_umol, DOY, latitude_deg=LATITUDE):
    """Direct and diffuse parts of above-canopy PAR at solar noon (Spitters et al., 1986, Eq. 20).

    The diffuse fraction depends on the ratio of PAR to the extraterrestrial PAR on a
    horizontal surface, taken as 2400 cos(zenith) umol m-2 s-1.
    """
    z_rad = solar_zenith_rad(DOY, latitude_deg, 0.0)
    cos_z = np.cos(z_rad); sin_beta = cos_z
    PAR_TOA = 2400.0 * cos_z
    if PAR_TOA < 1:
        return 0.0, PAR_above_umol
    tau = float(np.clip(PAR_above_umol / PAR_TOA, 0.0, 1.0))
    R = 0.847 - 1.61 * sin_beta + 1.04 * sin_beta ** 2
    K = (1.47 - R) / 1.66
    if tau <= 0.22:   fd = 1.0
    elif tau <= 0.35: fd = 1.0 - 6.4 * (tau - 0.22) ** 2
    elif tau <= K:    fd = 1.47 - 1.66 * tau
    else:             fd = R
    fd = float(np.clip(fd, 0.0, 1.0))
    return PAR_above_umol * (1.0 - fd), PAR_above_umol * fd


def G_planophile(zenith_rad, n_int=200):
    """Mean projection of unit leaf area toward zenith_rad (G function) for the de Wit (1965)
    planophile leaf-angle distribution, by numerical integration over leaf inclination."""
    theta_L = np.linspace(1e-6, np.pi / 2 - 1e-6, n_int)
    f_LAD = (2.0 / np.pi) * (1.0 + np.cos(2.0 * theta_L))
    cos_zs, sin_zs = np.cos(zenith_rad), np.sin(zenith_rad)
    cos_tL, sin_tL = np.cos(theta_L), np.sin(theta_L)
    A_arr = np.where(zenith_rad + theta_L <= np.pi / 2,
                     cos_zs * cos_tL,
                     np.where((sin_zs * sin_tL) > 1e-9,
                              cos_zs * cos_tL * (1.0 + (2.0 / np.pi) * (
                                  np.sqrt(np.maximum((sin_zs * sin_tL) ** 2 - (cos_zs * cos_tL) ** 2, 0.0))
                                  / np.maximum(cos_zs * cos_tL, 1e-9)
                                  - np.arccos(np.clip((cos_zs * cos_tL) / np.maximum(sin_zs * sin_tL, 1e-9), -1.0, 1.0)))),
                              cos_zs * cos_tL))
    return float(np.trapezoid(f_LAD * np.maximum(A_arr, 0.0), theta_L))


def compute_kd_planophile(LAI_total, n_int_zen=64):
    """Extinction coefficient of diffuse light for a planophile canopy of total LAI LAI_total,
    from the transmission of light from a uniform sky integrated over zenith angles."""
    if LAI_total < 0.01:
        return 0.78
    theta_s = np.linspace(1e-3, np.pi / 2 - 1e-3, n_int_zen)
    cos_z, sin_z = np.cos(theta_s), np.sin(theta_s)
    kb_vals = np.array([G_planophile(t) for t in theta_s]) / np.maximum(cos_z, 1e-3)
    weights = sin_z * cos_z
    tau_d = np.trapezoid(np.exp(-kb_vals * LAI_total) * weights, theta_s) / np.trapezoid(weights, theta_s)
    return float(-np.log(max(tau_d, 1e-9)) / LAI_total)


def compute_rho_d(sigma, n_int_zen=64):
    """Canopy reflection coefficient of diffuse light for leaf scattering coefficient sigma,
    the beam reflection coefficient of de Pury & Farquhar (1997) averaged over a uniform sky."""
    rho_h = (1.0 - np.sqrt(1.0 - sigma)) / (1.0 + np.sqrt(1.0 - sigma))
    theta_s = np.linspace(1e-3, np.pi / 2 - 1e-3, n_int_zen)
    cos_z, sin_z = np.cos(theta_s), np.sin(theta_s)
    kb_vals = np.array([G_planophile(t) for t in theta_s]) / np.maximum(cos_z, 1e-3)
    rho_cb_vals = 1.0 - np.exp(-2.0 * rho_h * kb_vals / (1.0 + kb_vals))
    weights = sin_z * cos_z
    return float(np.trapezoid(rho_cb_vals * weights, theta_s) / np.trapezoid(weights, theta_s))


def absorbed_irradiance_profile(I_b_above, I_d_above, sigma, kb, kd, rho_d_band, cum_LAI):
    """Absorbed beam and diffuse irradiance per unit leaf area of sunlit and shaded leaves.

    Two-stream equations of de Pury & Farquhar (1997, Eqs. A2-A8, with the canopy beam
    reflection coefficient of Eq. A19) at the cumulative LAI values cum_LAI. The band scatter
    coefficient sigma makes the same function serve PAR and NIR.
    Returns (I_sun_total, I_shade_total) in the units of I_b_above and I_d_above.
    """
    kb_prime = kb * np.sqrt(1 - sigma)
    kd_prime = kd * np.sqrt(1 - sigma)
    rho_h = (1.0 - np.sqrt(1.0 - sigma)) / (1.0 + np.sqrt(1.0 - sigma))
    rho_cb = 1.0 - np.exp(-2.0 * rho_h * kb / (1.0 + kb))
    I_sun_b = (1.0 - sigma) * kb * I_b_above
    I_diffuse = I_d_above * (1.0 - rho_d_band) * kd_prime * np.exp(-kd_prime * cum_LAI)
    I_bs = I_b_above * ((1.0 - rho_cb) * kb_prime * np.exp(-kb_prime * cum_LAI)
                        - (1.0 - sigma) * kb * np.exp(-kb * cum_LAI))
    I_bs = np.maximum(I_bs, 0.0)
    return I_sun_b + I_diffuse + I_bs, I_diffuse + I_bs


# ============================================================
# Boundary layer, BMF stomata and leaf energy balance, as in Helios
# ============================================================
def pohlhausen_gH(U, L):
    """Boundary-layer conductance to heat, mol m-2 s-1 (Helios Pohlhausen)."""
    U = max(U, 1e-3); L = max(L, 1e-3)
    return 0.135 * np.sqrt(U / L) * NSIDES


def bmf_gs_and_esurf(PAR_W, es, ea, press_Pa, gbw):
    """Co-solve BMF gs (mol m-2 s-1) and leaf-surface vapor pressure esurf.

    gs  = Em*beta*(i+i0)/(k + b*i + (i+i0)*Ds),  i = PAR_W*4.57 (umol m-2 s-1)
    Ds  = (es - esurf)/press*1000   (mmol/mol)
    esurf from flux balance gs*(es-esurf)=gbw*(esurf-ea):
        esurf = (gs*es + gbw*ea)/(gs + gbw)
    Solved by fixed-point iteration, which converges fast because gs depends weakly on esurf.
    """
    i = PAR_W * PAR_W_TO_UMOL_HELIOS
    esurf = ea + 0.1 * (es - ea)        # Helios initial guess
    for _ in range(50):
        Ds = max(0.0, (es - esurf) / press_Pa * 1000.0)
        # The BMF formula gives gs in mol m-2 s-1, as in Helios.
        gs = BMF_Em * BMF_BETA * (i + BMF_i0) / (BMF_k + BMF_b * i + (i + BMF_i0) * Ds)
        esurf_new = (gs * es + gbw * ea) / (gs + gbw)
        if abs(esurf_new - esurf) < 1e-3:
            esurf = esurf_new; break
        esurf = esurf_new
    return gs, esurf


def solve_leaf_T(R_sw, gH, gs, Ta_K, ea, press_Pa):
    """Solve leaf temperature from the Helios energy-balance residual.

    R_sw  : absorbed shortwave (PAR+NIR), W m-2 (per leaf)
    LW    : exchange with surroundings at air temperature (LW_ENV_AT_AIR_T),
            net LW = Nsides*eps*sigma*(Ta^4 - T^4), or zero when LW_OFF
    QH    : cp_air_mol * gH * (T - Ta)
    QL    : gM * lambda_mol * (es(T) - ea*surfhum)/press
            gM = 1.08*gH*gs/(1.08*gH + gs)   [one-sided stomata series form]
    Returns air temperature when the residual has no root in Ta - 25 K to Ta + 35 K.
    """
    gbw = GBW_OVER_GH * gH
    gM = gbw * gs / (gbw + gs) if (gbw + gs) > 0 else 0.0

    def residual(T):
        es = esat_Pa(T)
        if LW_OFF:
            net_lw = 0.0
        elif LW_ENV_AT_AIR_T:
            net_lw = NSIDES * EPS_LEAF * SIGMA_SB * (Ta_K ** 4 - T ** 4)
        else:
            net_lw = -NSIDES * EPS_LEAF * SIGMA_SB * T ** 4
        QH = CP_AIR_MOL * gH * (T - Ta_K)
        QL = gM * LAMBDA_MOL * (es - ea * SURFACE_HUMIDITY) / press_Pa
        return R_sw + net_lw - QH - QL

    try:
        return brentq(residual, Ta_K - 25.0, Ta_K + 35.0, xtol=1e-4, maxiter=200)
    except ValueError:
        return Ta_K   # leaf temperature taken as air temperature when the bracket holds no root


def solve_A_Ci(PAR_umol, Vcmax25, Jmax25, Rd25, Tp25, T_K, gs_h2o, Ca):
    """Solve assimilation A with diffusion-coupled Ci = Ca - 1.6*A/gs (CO2)."""
    if gs_h2o <= 0:
        return fvcb_A_at(PAR_umol, Vcmax25, Jmax25, Rd25, Tp25, T_K, 0.7 * Ca)
    gs_co2 = gs_h2o / 1.6
    Ci = 0.7 * Ca
    for _ in range(50):
        A = fvcb_A_at(PAR_umol, Vcmax25, Jmax25, Rd25, Tp25, T_K, Ci)
        Ci_target = float(np.clip(Ca - A / gs_co2, 0.05 * Ca, Ca))
        Ci_new = 0.5 * (Ci + Ci_target)   # damped to prevent oscillation
        if abs(Ci_new - Ci) < 0.1:
            Ci = Ci_new; break
        Ci = Ci_new
    return fvcb_A_at(PAR_umol, Vcmax25, Jmax25, Rd25, Tp25, T_K, Ci)


def canopy_A_EB(LAI, Vcmax25_top, Jmax25_top, Rd25, Tp25, Ta_C, Ca, RH,
                U, leaf_L, press_Pa, DOY,
                PAR_b_W, PAR_d_W, NIR_b_W, NIR_d_W, sigma_nir):
    """Sun-shade canopy A with an energy balance and BMF stomata for each leaf class.

    Returns canopy A (umol m-2 s-1 of ground) and the mean leaf temperatures (deg C) of
    sunlit and shaded leaves, weighted by their leaf area in each layer.
    """
    if LAI < 0.01:
        return 0.0, np.nan, np.nan
    Ta_K = Ta_C + 273.15
    ea = RH * esat_Pa(Ta_K)
    z = solar_zenith_rad(DOY)
    cos_z = max(np.cos(z), 0.01)
    kb = G_planophile(z) / cos_z
    kd = compute_kd_planophile(LAI)
    rho_d_par = compute_rho_d(SIGMA_PAR)
    rho_d_nir = compute_rho_d(sigma_nir)

    dLAI = LAI / N_LAYERS
    cum_LAI = np.linspace(dLAI / 2.0, LAI - dLAI / 2.0, N_LAYERS)
    f_sun = np.exp(-kb * cum_LAI); f_shade = 1.0 - f_sun

    # Absorbed PAR (W m-2, converted to umol for photosynthesis) and absorbed NIR (W m-2, for
    # the energy balance only).
    aPAR_sun_W, aPAR_sh_W = absorbed_irradiance_profile(PAR_b_W, PAR_d_W, SIGMA_PAR, kb, kd, rho_d_par, cum_LAI)
    aNIR_sun_W, aNIR_sh_W = absorbed_irradiance_profile(NIR_b_W, NIR_d_W, sigma_nir, kb, kd, rho_d_nir, cum_LAI)

    Vcmax25_layer = Vcmax25_top * np.exp(-K_N * (cum_LAI / LAI))
    gH = pohlhausen_gH(U, leaf_L)

    A_tot = 0.0; T_sun_mean = 0.0; T_sh_mean = 0.0
    for i in range(N_LAYERS):
        # --- sunlit ---
        Rsw_sun = aPAR_sun_W[i] + aNIR_sun_W[i]
        es0 = esat_Pa(Ta_K)
        gs_sun, _ = bmf_gs_and_esurf(aPAR_sun_W[i], es0, ea, press_Pa, GBW_OVER_GH * gH)
        T_sun = solve_leaf_T(Rsw_sun, gH, gs_sun, Ta_K, ea, press_Pa)
        # gs again at the solved leaf temperature, then A
        gs_sun, _ = bmf_gs_and_esurf(aPAR_sun_W[i], esat_Pa(T_sun), ea, press_Pa, GBW_OVER_GH * gH)
        A_sun = solve_A_Ci(aPAR_sun_W[i] * PAR_W_TO_UMOL, Vcmax25_layer[i], Jmax25_top,
                           Rd25, Tp25, T_sun, gs_sun, Ca)
        # --- shaded ---
        Rsw_sh = aPAR_sh_W[i] + aNIR_sh_W[i]
        gs_sh, _ = bmf_gs_and_esurf(aPAR_sh_W[i], es0, ea, press_Pa, GBW_OVER_GH * gH)
        T_sh = solve_leaf_T(Rsw_sh, gH, gs_sh, Ta_K, ea, press_Pa)
        gs_sh, _ = bmf_gs_and_esurf(aPAR_sh_W[i], esat_Pa(T_sh), ea, press_Pa, GBW_OVER_GH * gH)
        A_sh = solve_A_Ci(aPAR_sh_W[i] * PAR_W_TO_UMOL, Vcmax25_layer[i], Jmax25_top,
                          Rd25, Tp25, T_sh, gs_sh, Ca)

        A_tot += (A_sun * f_sun[i] + A_sh * f_shade[i]) * dLAI
        T_sun_mean += T_sun * f_sun[i]; T_sh_mean += T_sh * f_shade[i]

    return float(A_tot), float(T_sun_mean / max(f_sun.sum(), 1e-9)) - 273.15, \
        float(T_sh_mean / max(f_shade.sum(), 1e-9)) - 273.15


# ============================================================
# Run over all plot-dates
# ============================================================
def main():
    t0 = datetime.now()
    print(f"One-dimensional sun-shade model, output suffix '{RUN_TAG}'")
    print(f"  CONFIG: GBW/GH={GBW_OVER_GH}  LEAF_SUBDIV_FACTOR={LEAF_SUBDIV_FACTOR}  "
          f"LW_env_at_airT={LW_ENV_AT_AIR_T}  LW_off={LW_OFF}  NIR_from_SlrFD={USE_SLRFD_FOR_NIR}")

    # Helios canopy summaries of both sites. Rows with missing values or with non-positive
    # Vcmax25 or Jmax25 are dropped.
    df = pd.concat([pd.read_csv(HELIOS_OUT / f"helios_canopy_summary_{s}.csv")
                    for s in ("EF", "SF")], ignore_index=True)
    df = df.dropna(subset=["A_umol_m2_s", "LAI_used", "Vcmax25_used", "Jmax25_used",
                           "air_T_C_used", "RH_fraction_used", "incident_PAR_W_m2",
                           "DOY", "CO2_ppm_used"])
    df = df[(df["Vcmax25_used"] > 0) & (df["Jmax25_used"] > 0)].copy()
    print(f"  3D rows: {len(df)}  unique plots: {df['Loc_ID'].nunique()}")

    # Per-plot inputs of each plot-date: biochemistry, weather, leaf optics and leaflet size.
    need = ["Loc_ID", "DAP", "rd25", "tp25", "tp25_source", "wind_m_s", "BP_Pa",
            "SlrFD_kW_m2", "R_PAR_leaf", "T_PAR_leaf", "R_NIR_leaf", "T_NIR_leaf",
            "length_m", "avwidth_m"]
    ci = pd.concat([pd.read_csv(INPUTS_DIR / f"canopy_inputs_per_plot_per_DAP_{s}.csv")
                    for s in ("EF", "SF")], ignore_index=True)
    missing = [c for c in need if c not in ci.columns]
    if missing:
        raise SystemExit(f"ERROR: canopy_inputs missing columns {missing}; check INPUTS_DIR file.")
    df = df.merge(ci[need].drop_duplicates(subset=["Loc_ID", "DAP"]),
                  on=["Loc_ID", "DAP"], how="left")
    df = df.dropna(subset=["rd25", "tp25", "wind_m_s", "length_m", "avwidth_m"]).copy()
    print(f"  after join: {len(df)} rows")

    # Above-canopy PAR in umol m-2 s-1, from the incident PAR of the Helios run (W m-2).
    df["PAR_above_umol"] = df["incident_PAR_W_m2"] * PAR_W_TO_UMOL

    def per_row(r):
        PAR_b_u, PAR_d_u = spitters_direct_diffuse(r["PAR_above_umol"], r["DOY"])
        # The diffuse fraction of PAR is also applied to NIR.
        fd = PAR_d_u / max(PAR_b_u + PAR_d_u, 1e-9)
        PAR_W = r["incident_PAR_W_m2"]
        PAR_b_W, PAR_d_W = PAR_W * (1 - fd), PAR_W * fd
        # Incident NIR is station shortwave (kW m-2 converted to W m-2) minus PAR, or PAR
        # itself when CFG_NIR_SLRFD=0.
        SW_W = r["SlrFD_kW_m2"] * 1000.0 if USE_SLRFD_FOR_NIR else 2.0 * PAR_W
        NIR_W = max(0.0, SW_W - PAR_W)
        NIR_b_W, NIR_d_W = NIR_W * (1 - fd), NIR_W * fd
        # Leaf scattering coefficient of NIR (reflectance + transmittance) and leaf
        # characteristic length.
        sigma_nir = float(np.clip(r["R_NIR_leaf"] + r["T_NIR_leaf"], 0.01, 0.99))
        leaf_L = np.sqrt(max(r["length_m"] * r["avwidth_m"], 1e-6)) / LEAF_SUBDIV_FACTOR
        A, Tsun, Tsh = canopy_A_EB(
            LAI=r["LAI_used"], Vcmax25_top=r["Vcmax25_used"], Jmax25_top=r["Jmax25_used"],
            Rd25=r["rd25"], Tp25=r["tp25"], Ta_C=r["air_T_C_used"], Ca=r["CO2_ppm_used"],
            RH=r["RH_fraction_used"], U=r["wind_m_s"], leaf_L=leaf_L, press_Pa=r["BP_Pa"],
            DOY=r["DOY"], PAR_b_W=PAR_b_W, PAR_d_W=PAR_d_W, NIR_b_W=NIR_b_W, NIR_d_W=NIR_d_W,
            sigma_nir=sigma_nir)
        return pd.Series({"canopy_A_DePuryEB": A, "Tleaf_sun_C": Tsun, "Tleaf_shade_C": Tsh})

    print("  running per row ...")
    res = df.apply(per_row, axis=1)
    df = pd.concat([df, res], axis=1)

    # Helios minus 1D canopy A, absolute and in percent of Helios.
    df["delta_3D_arch_EB"] = df["A_umol_m2_s"] - df["canopy_A_DePuryEB"]
    df["pct_3D_arch_EB"] = 100.0 * df["delta_3D_arch_EB"] / df["A_umol_m2_s"].replace(0, np.nan)

    out_cols = ["Loc_ID", "Site", "Spacing", "Leaf_type", "DAP", "DOY",
                "LAI_used", "Vcmax25_used", "Jmax25_used", "rd25", "tp25",
                "air_T_C_used", "RH_fraction_used", "wind_m_s", "incident_PAR_W_m2",
                "CO2_ppm_used", "Tleaf_sun_C", "Tleaf_shade_C",
                "A_umol_m2_s", "canopy_A_DePuryEB", "delta_3D_arch_EB", "pct_3D_arch_EB"]
    out_csv = OUT / f"helios_vs_1D_per_plot{RUN_TAG}.csv"
    df[out_cols].to_csv(out_csv, index=False)
    print(f"  wrote: {out_csv}")

    # Agreement of the two models and the mean difference per class.
    r_all = float(np.corrcoef(df["A_umol_m2_s"], df["canopy_A_DePuryEB"])[0, 1])
    rmse = float(np.sqrt(np.mean((df["A_umol_m2_s"] - df["canopy_A_DePuryEB"]) ** 2)))
    bias = float(np.mean(df["delta_3D_arch_EB"]))
    summ = OUT / f"helios_vs_1D_summary{RUN_TAG}.txt"
    with open(summ, "w", encoding="utf-8") as f:
        f.write("One-dimensional sun-shade model with the Helios energy balance and BMF stomata (1D+EB) vs Helios 3D\n")
        f.write(f"CONFIG: GBW/GH={GBW_OVER_GH}, LEAF_SUBDIV_FACTOR={LEAF_SUBDIV_FACTOR}, "
                f"LW_env_at_airT={LW_ENV_AT_AIR_T}, LW_off={LW_OFF}, NIR_from_SlrFD={USE_SLRFD_FOR_NIR}\n")
        f.write("=" * 70 + "\n")
        f.write(f"rows: {len(df)}   unique plots: {df['Loc_ID'].nunique()}\n")
        f.write(f"Pearson r (3D vs 1D+EB): {r_all:+.4f}\nRMSE: {rmse:.3f}\nbias (3D-1D): {bias:+.3f}\n\n")
        f.write("--- delta_3D = 3D - (1D+EB) per (Site,Spacing,Leaf_type) ---\n")
        for key, sub in df.groupby(["Site", "Spacing", "Leaf_type"]):
            s = sub["delta_3D_arch_EB"]
            f.write(f"  {key[0]} {ROW_SPACING_CM[key[1]]} {key[2]:6s} n={len(sub):4d} "
                    f"delta={s.mean():+.3f} +/- {s.std():.3f}\n")
    print(f"  wrote: {summ}")
    print(f"  r={r_all:+.4f} RMSE={rmse:.3f} bias={bias:+.3f}  "
          f"done in {(datetime.now()-t0).total_seconds():.1f}s")


if __name__ == "__main__":
    main()
