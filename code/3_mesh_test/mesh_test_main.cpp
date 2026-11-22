// Helios sub-leaf mesh test of canopy photosynthesis at a chosen number of elements per leaflet
//
// Purpose
//   Runs the Helios canopy simulation of code/2_helios_simulation/helios_main.cpp for the
//   class-mean canopy of one location x row spacing x leaflet type combination on its
//   peak-LAI date, with each leaflet divided into NX x NY sub-leaf elements. The task list
//   runs the eight class-mean canopies with 1, 4, 9, 25, 64, 144 and 225 elements per leaflet
//   (NX = NY = 1, 2, 3, 5, 8, 12 and 15). The results are in Fig S8B-C and Table S12, and the
//   per-element outputs at 144 elements per leaflet give the comparison at the end of
//   Methods S1.10.
//
//   The simulation code is that of helios_main.cpp. This driver differs from it in five places.
//     1. Two global variables, g_N_sub_x and g_N_sub_y, hold the sub-leaf grid.
//     2. The arguments are <SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>. The canopy
//        identifier is built from them as <SITE>_<SPACING>_<LEAF_TYPE>_DAP<NNN>, for example
//        EF_15_Broad_DAP061, which is the Loc_ID of that canopy in the input file.
//        USE_CELL_MEAN_VCMAX is fixed at 0, because the input rows already hold class means.
//     3. One input file, ../inputs/mesh_test_inputs.csv, serves as both the per-plot input
//        and the class-mean lookup.
//     4. cp.leaf_subdivisions is make_int2(NX, NY) instead of make_int2(3, 3).
//     5. The summary file name ends in _N<NX>x<NY>, and the summary gains three columns,
//        N_sub_x, N_sub_y and N_sub_total (= NX x NY).
//
// Inputs (relative to the working directory, which must be build/ in the project folder, see
//   docs/cluster_run.md)
//   ../inputs/mesh_test_inputs.csv   the eight class-mean canopies (data/simulation_inputs/ in
//       the package, written by scripts/01_make_mesh_test_inputs.py)
//
// Outputs (relative to the working directory)
//   outputs/<SITE>/per_task/canopy_summary_<SITE>_<SPACING>_<LEAF_TYPE>_DAP<NNN>_N<NX>x<NY>.csv
//       one-row canopy summary
//   outputs/<SITE>/per_leaf/<SITE>_<SPACING>_<LEAF_TYPE>_DAP<NNN>_DAP<NNN>.csv   one row per
//       sub-leaf element, as in helios_main.cpp. The file name does not contain the sub-leaf
//       grid, so the seven runs of one canopy write the same file and the file kept is the
//       one from the run that finished last.
//   scripts/05_combine_outputs.sh joins the 56 per-task summaries into
//   outputs/mesh_test/mesh_test_summary.csv.
//
// Usage
//   ./helios_mesh_test <SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>
//   for example, from build/:   ./helios_mesh_test EF 15 Broad 61 3 3
//   scripts/04_submit_array.sh makes one such call for each line of the task list.
//
// Requirements
//   Helios 1.3.71 (commit c710cdfb) with the radiation, energybalance, stomatalconductance,
//   boundarylayerconductance, solarposition, canopygenerator and photosynthesis plugins;
//   CMake, a C++ compiler, CUDA and an NVIDIA GPU (docs/helios_build.md)
//
// Canopy light-use terms in the summary (Long et al., 2006)
//   frac_PAR_absorbed                              canopy absorbed PAR / incident PAR (fAPAR)
//   inst_canopy_A_per_abs_PAR_umol_per_umol        canopy A / absorbed PAR (canopy LUE)
//   inst_canopy_A_per_incident_PAR_umol_per_umol   canopy A / incident PAR (fAPAR x LUE)

#include "BoundaryLayerConductanceModel.h"
#include "CanopyGenerator.h"
#include "EnergyBalanceModel.h"
#include "PhotosynthesisModel.h"
#include "RadiationModel.h"
#include "SolarPosition.h"
#include "StomatalConductanceModel.h"

#include <cmath>
#include <ctime>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <unordered_map>
#include <vector>

using namespace helios;

// ============================================================
// Constants
// ============================================================
constexpr float PAR_W_TO_UMOL   = 4.6f;    // umol photons per J of PAR (Thimijan & Heins, 1983)
constexpr float K_VCMAX_PROFILE = 0.64f;   // coefficient of the Vcmax25 profile (Wang et al., 2026)
constexpr float CO2_PPM         = 415.0f;  // ambient CO2, ppm
constexpr float TURBIDITY       = 0.05f;   // aerosol turbidity of the clear-sky solar model
constexpr float EMISS_LW        = 0.95f;   // emissivity of leaves and ground
const     float LAT             = 40.063476f;  // latitude of the Energy Farm, degrees N (both sites)
const     float LON             = 88.206586f;  // longitude of the Energy Farm, degrees W (both sites)
const     int   UTC_OFFSET      = 5;        // hours behind UTC (Central Daylight Time)

// ============================================================
// One row of the input file (one canopy on one date)
// ============================================================
struct PlotDAP {
    std::string Loc_ID;             // canopy identifier, for example "EF_15_Broad_DAP061"
    std::string Site;               // "EF" (Energy Farm) or "SF" (SoyFACE)
    int         Spacing;            // row spacing, 38-cm rows (15) or 76-cm rows (30)
    std::string Leaf_type;          // "Broad" or "Narrow"
    int         DAP;                // days after planting
    int         DOY;                // day of year
    std::string date_iso;           // date as YYYY-MM-DD, derived from DOY
    float       LAI;                // LAI, m2 m-2
    float       height_m;           // plant height, m
    float       leaf_length_m;      // leaflet length, m
    float       leaf_avwidth_m;     // average leaflet width, m
    float       Vcmax25;            // Vcmax25 at the canopy top, umol m-2 s-1 (-1 when missing)
    float       Jmax25;             // Jmax25, umol m-2 s-1 (-1 when missing)
    float       rd25 = -1.0f;       // Rd25, umol m-2 s-1. -1 = not set.
    float       tp25 = -1.0f;       // Tp25, umol m-2 s-1. -1 = not set.
    // Leaf PAR and NIR reflectance and transmittance from PROSPECT-D forward runs
    // (Methods S1.3). -1 = not set.
    float       R_PAR_leaf = -1.0f;
    float       T_PAR_leaf = -1.0f;
    float       R_NIR_leaf = -1.0f;
    float       T_NIR_leaf = -1.0f;
    int         Vcmax_n = -1;       // source of Vcmax25, written to the summary:
                                    //   1 = value of the input row,
                                    //   > 1 = class mean of that many plants,
                                    //   0 = class mean without measurements,
                                    //   -1 = not set.
                                    // main() sets it for the task being run. The default
                                    // keeps the field defined on every code path.
    int         Jmax_n  = -1;       // source of Jmax25, coded as Vcmax_n
    float       air_T_C;            // air temperature, deg C
    float       air_T_K;            // air temperature, K
    float       BP_Pa;              // barometric pressure, Pa
    float       RH_fraction;        // relative humidity, fraction
    float       wind_m_s;           // wind speed, m s-1
};

// ============================================================
// CSV helpers
// ============================================================
// Splits one CSV line into fields. Double quotes are removed, and commas inside quotes do not
// split fields.
std::vector<std::string> split_csv(const std::string &line) {
    std::vector<std::string> out;
    std::string field;
    bool in_quote = false;
    for (char c : line) {
        if (c == '"') in_quote = !in_quote;
        else if (c == ',' && !in_quote) { out.push_back(field); field.clear(); }
        else field += c;
    }
    out.push_back(field);
    return out;
}

// String to number conversion. An empty field returns the fallback value fb. A field that
// cannot be converted is reported on stderr and also returns fb.
float to_float(const std::string &s, float fb = 0.0f) {
    if (s.empty()) return fb;
    try { return std::stof(s); } catch (const std::exception &e) {
        std::cerr << "[to_float caught] s='" << s.substr(0, 50) << "' -> fb=" << fb << " (" << e.what() << ")" << std::endl;
        return fb;
    } catch (...) { return fb; }
}
int to_int(const std::string &s, int fb = 0) {
    if (s.empty()) return fb;
    try { return std::stoi(s); } catch (const std::exception &e) {
        std::cerr << "[to_int caught] s='" << s.substr(0, 50) << "' -> fb=" << fb << " (" << e.what() << ")" << std::endl;
        return fb;
    } catch (...) { return fb; }
}

// ============================================================
// Read the input file
// ============================================================
// Returns one PlotDAP per row of a BC3 canopy. Columns are found by their header names.
// Progress messages go to stderr.
std::vector<PlotDAP> read_per_plot_csv(const std::string &path, const std::string &site) {
    std::cerr << "[read_per_plot_csv] enter, path=" << path << std::endl;
    std::ifstream f(path);
    if (!f) {
        std::cerr << "ERROR: cannot open " << path << std::endl;
        std::exit(1);
    }
    std::cerr << "[read_per_plot_csv] file opened OK" << std::endl;
    std::string line;
    std::getline(f, line);
    std::cerr << "[read_per_plot_csv] header line size=" << line.size() << std::endl;
    auto headers = split_csv(line);
    std::cerr << "[read_per_plot_csv] header field count=" << headers.size() << std::endl;
    std::unordered_map<std::string, int> col;
    for (size_t i = 0; i < headers.size(); i++) col[headers[i]] = static_cast<int>(i);
    std::cerr << "[read_per_plot_csv] col map built, e.g. col[Line]=" << col["Line"]
              << " col[Spacing]=" << col["Spacing"]
              << " col[DAP]=" << col["DAP"]
              << " col[vcmax]=" << col["vcmax"]
              << " col[R_PAR_leaf]=" << col["R_PAR_leaf"] << std::endl;

    std::vector<PlotDAP> rows;
    int row_idx = 0;
    while (std::getline(f, line)) {
        ++row_idx;
        if (line.empty()) continue;
        auto fields = split_csv(line);
        if (row_idx <= 3 || row_idx % 500 == 0) {
            std::cerr << "[row " << row_idx << "] fields.size()=" << fields.size()
                      << " first=" << fields[0]
                      << " line_size=" << line.size() << std::endl;
        }
        // Keep the BC3 near-isogenic line canopies only.
        std::string lineLabel = (col.count("Line") && col["Line"] < (int)fields.size()) ? fields[col["Line"]] : "";
        if (lineLabel != "BC3") continue;

        PlotDAP r;
        r.Loc_ID         = fields[col["Loc_ID"]];
        r.Site           = site;
        r.Spacing        = to_int(fields[col["Spacing"]]);
        r.Leaf_type      = fields[col["Leaf_type"]];
        r.DAP            = to_int(fields[col["DAP"]]);
        r.DOY            = to_int(fields[col["DOY"]]);
        // Date of the 2024 season from the day of year. mktime() normalizes day DOY of
        // January to the calendar date, so the leap year is handled. The simulation date is
        // set from this string in run_one_simulation().
        {
            int yr = 2024;
            struct tm t = {};
            t.tm_year = yr - 1900;
            t.tm_mon  = 0;
            t.tm_mday = r.DOY;
            t.tm_hour = 12;
            mktime(&t);
            char buf[32];
            snprintf(buf, sizeof(buf), "%04d-%02d-%02d", yr, t.tm_mon + 1, t.tm_mday);
            r.date_iso = std::string(buf);
        }
        r.LAI            = to_float(fields[col["LAI_m2_m2_interp"]]);
        r.height_m       = to_float(fields[col["height_m_interp"]]);
        r.leaf_length_m  = to_float(fields[col["length_m"]]);
        r.leaf_avwidth_m = to_float(fields[col["avwidth_m"]]);
        // Vcmax25 and Jmax25 are -1 when the field is empty. main() then substitutes the
        // class mean.
        r.Vcmax25        = to_float(fields[col["vcmax"]], -1.0f);
        r.Jmax25         = to_float(fields[col["jmax"]],  -1.0f);
        // Rd25 (column rd25), Tp25 (column tp25), and leaf PAR and NIR reflectance and
        // transmittance (PROSPECT-D, Methods S1.3). In the mesh-test inputs these are the
        // means over the plots of the class on the peak-LAI date.
        r.rd25           = to_float(fields[col["rd25"]],  -1.0f);
        r.tp25           = to_float(fields[col["tp25"]],  -1.0f);
        r.R_PAR_leaf     = to_float(fields[col["R_PAR_leaf"]], -1.0f);
        r.T_PAR_leaf     = to_float(fields[col["T_PAR_leaf"]], -1.0f);
        r.R_NIR_leaf     = to_float(fields[col["R_NIR_leaf"]], -1.0f);
        r.T_NIR_leaf     = to_float(fields[col["T_NIR_leaf"]], -1.0f);
        r.air_T_C        = to_float(fields[col["air_T_C"]]);
        r.air_T_K        = to_float(fields[col["air_T_K"]]);
        r.BP_Pa          = to_float(fields[col["BP_Pa"]]);
        r.RH_fraction    = to_float(fields[col["RH_fraction"]]);
        r.wind_m_s       = to_float(fields[col["wind_m_s"]]);
        rows.push_back(r);
    }
    return rows;
}

// ============================================================
// Class-mean Vcmax25 and Jmax25 lookup
// ============================================================
// Keyed by "<Spacing>_<Leaf_type>". The mesh test reads it from the same input file, and the
// lookup is never used because every input row holds both values.
struct CellBiochem {
    // The defaults (NaN and -1) make a missing value visible in the outputs.
    float Vcmax25_cell_mean = std::numeric_limits<float>::quiet_NaN();
    float Jmax25_cell_mean  = std::numeric_limits<float>::quiet_NaN();
    int   Vcmax_n = -1;
    int   Jmax_n  = -1;
};

std::unordered_map<std::string, CellBiochem> read_cell_biochem(const std::string &path) {
    std::ifstream f(path);
    if (!f) {
        std::cerr << "ERROR: cannot open cell-mean lookup " << path << std::endl;
        std::exit(1);
    }
    std::string line;
    std::getline(f, line);
    auto headers = split_csv(line);
    std::unordered_map<std::string, int> col;
    for (size_t i = 0; i < headers.size(); i++) col[headers[i]] = static_cast<int>(i);

    std::unordered_map<std::string, CellBiochem> map;
    while (std::getline(f, line)) {
        if (line.empty()) continue;
        auto fields = split_csv(line);
        std::string key = fields[col["Spacing"]] + "_" + fields[col["Leaf_type"]];
        // Keep the first row of each class.
        if (map.find(key) == map.end()) {
            CellBiochem cb;
            cb.Vcmax25_cell_mean = to_float(fields[col["Vcmax25"]]);
            cb.Jmax25_cell_mean  = to_float(fields[col["Jmax25"]]);
            cb.Vcmax_n           = to_int(fields[col["Vcmax_n"]]);
            cb.Jmax_n            = to_int(fields[col["Jmax_n"]]);
            map[key] = cb;
        }
    }
    return map;
}

// ============================================================
// Sub-leaf grid of this run
// ============================================================
// NX and NY are set from the arguments in main() and used for cp.leaf_subdivisions in
// run_one_simulation().
static int g_N_sub_x = 3;
static int g_N_sub_y = 3;

// ============================================================
// Simulate one canopy on one date
// ============================================================
// Builds the canopy, solves the radiation, stomatal, energy-balance and photosynthesis models,
// writes the per-element file to per_leaf_dir and appends one summary row to summary_out.
void run_one_simulation(const PlotDAP &r, std::ofstream &summary_out,
                        const std::string &per_leaf_dir) {
    std::cout << "\n=== Sim: Loc_ID=" << r.Loc_ID
              << "  Spacing=" << r.Spacing
              << "  Leaf=" << r.Leaf_type
              << "  DAP=" << r.DAP
              << "  date=" << r.date_iso << " ===" << std::endl;
    std::cout << "  LAI=" << r.LAI << " m2/m2; height=" << r.height_m << " m; "
              << "leaf=" << r.leaf_length_m << "x" << r.leaf_avwidth_m << " m" << std::endl;
    std::cout << "  Vcmax25_top=" << r.Vcmax25
              << ", Jmax25=" << r.Jmax25 << std::endl;
    std::cout << "  T=" << r.air_T_C << " C, RH=" << r.RH_fraction
              << ", wind=" << r.wind_m_s << " m/s, BP=" << r.BP_Pa << " Pa" << std::endl;

    // Canopies with LAI or height below 0.05 are not simulated.
    if (r.LAI < 0.05f || r.height_m < 0.05f) {
        std::cout << "  SKIP: degenerate canopy (LAI/height too small)" << std::endl;
        return;
    }

    Context context;

    // Simulation date, and the time 12:00 local time (CDT).
    int year, month, day;
    sscanf(r.date_iso.c_str(), "%d-%d-%d", &year, &month, &day);
    context.setDate(Date(day, month, year));
    context.setTime(Time(12, 0, 0));

    // ============================================================
    // Canopy
    // ============================================================
    // Homogeneous canopy of leaflets with the class-mean length and average width, placed at
    // random over a 3 x 3 m area up to the canopy height, with planophile leaf angles. Each
    // leaflet is divided into NX x NY sub-leaf elements (3 x 3 in the main simulations).
    HomogeneousCanopyParameters cp;
    cp.leaf_size = make_vec2(r.leaf_length_m, r.leaf_avwidth_m);
    cp.leaf_subdivisions = make_int2(g_N_sub_x, g_N_sub_y);
    cp.leaf_color = RGBcolor(0.20f, 0.55f, 0.15f);
    cp.leaf_angle_distribution = "planophile";
    cp.leaf_area_index = r.LAI;
    cp.canopy_height = r.height_m;
    cp.canopy_extent = make_vec2(3.0f, 3.0f);
    cp.buffer = "z";

    // Leaves and a ground surface of the same extent. The ground texture path is relative to
    // the build folder, where the Helios build places the plugin files.
    CanopyGenerator canopy(&context);
    canopy.buildCanopy(cp);
    auto leaf_UUIDs = canopy.getLeafUUIDs();
    canopy.buildGround(make_vec3(0,0,0), cp.canopy_extent, make_int2(1,1), make_int2(2,2),
                       "plugins/canopygenerator/textures/dirt.jpg");
    auto ground_UUIDs = canopy.getGroundUUIDs();
    auto all_UUIDs = context.getAllUUIDs();
    std::cout << "  Canopy: " << leaf_UUIDs.size() << " leaflets" << std::endl;

    // Height of each sub-leaf element (mean z of its vertices) and the height range of the
    // canopy, used for the Vcmax25 profile.
    std::vector<float> leaf_z(leaf_UUIDs.size(), 0.0f);
    float z_min = 1e9f, z_max = -1e9f;
    for (size_t i = 0; i < leaf_UUIDs.size(); i++) {
        auto verts = context.getPrimitiveVertices(leaf_UUIDs[i]);
        float zc = 0.0f;
        for (auto &v : verts) zc += v.z;
        zc /= static_cast<float>(verts.size());
        leaf_z[i] = zc;
        if (zc < z_min) z_min = zc;
        if (zc > z_max) z_max = zc;
    }
    float z_range = (z_max > z_min) ? (z_max - z_min) : 1.0f;

    // ============================================================
    // Sun position and radiation bands
    // ============================================================
    // PAR and NIR are shortwave bands without emission, with three scattering iterations.
    // LW is the emitted longwave band. The boundaries are periodic in x and y.
    SolarPosition solar(UTC_OFFSET, LAT, LON, &context);
    RadiationModel radiation(&context);
    uint sun = radiation.addSunSphereRadiationSource();
    radiation.addRadiationBand("PAR");
    radiation.disableEmission("PAR");
    radiation.setScatteringDepth("PAR", 3);
    radiation.addRadiationBand("NIR");
    radiation.disableEmission("NIR");
    radiation.setScatteringDepth("NIR", 3);
    radiation.addRadiationBand("LW");
    radiation.enforcePeriodicBoundary("xy");

    // Optical properties. Leaves take the PAR and NIR reflectance and transmittance of the
    // input row (PROSPECT-D, Methods S1.3). The ground reflects 0.15 of PAR and 0.40 of NIR
    // and is one-sided.
    context.setPrimitiveData(leaf_UUIDs, "reflectivity_PAR",   r.R_PAR_leaf);
    context.setPrimitiveData(leaf_UUIDs, "transmissivity_PAR", r.T_PAR_leaf);
    context.setPrimitiveData(leaf_UUIDs, "reflectivity_NIR",   r.R_NIR_leaf);
    context.setPrimitiveData(leaf_UUIDs, "transmissivity_NIR", r.T_NIR_leaf);
    context.setPrimitiveData(ground_UUIDs, "reflectivity_PAR", 0.15f);
    context.setPrimitiveData(ground_UUIDs, "reflectivity_NIR", 0.40f);
    context.setPrimitiveData(ground_UUIDs, "twosided_flag", uint(0));
    radiation.updateGeometry();

    // ============================================================
    // Energy balance, boundary layer, stomata and photosynthesis
    // ============================================================
    // The energy balance uses the absorbed radiation of all three bands. Boundary-layer
    // conductance follows the Pohlhausen equation for leaves and the Helios ground model for
    // the soil. Stomatal conductance follows the Buckley-Mott-Farquhar model with the Helios
    // default coefficients (Buckley et al., 2003).
    EnergyBalanceModel eb(&context);
    eb.addRadiationBand("PAR"); eb.addRadiationBand("NIR"); eb.addRadiationBand("LW");
    BLConductanceModel bl(&context);
    bl.setBoundaryLayerModel(ground_UUIDs, "Ground");
    bl.setBoundaryLayerModel(leaf_UUIDs, "Pohlhausen");
    StomatalConductanceModel stomatal(&context);
    BMFcoefficients bmfc;
    stomatal.setModelCoefficients(bmfc);
    PhotosynthesisModel photo(&context);

    // Farquhar-von Caemmerer-Berry photosynthesis (Farquhar et al., 1980; Methods S1.4).
    //   Vcmax25 (canopy top), Jmax25, Rd25 and Tp25   from the input row
    //   O                  210, O2 partial pressure in mmol mol-1
    //   dH_Jmax            43.9 kJ mol-1, activation energy of Jmax (Sharkey et al., 2007)
    //   alpha              0.385, quantum efficiency of electron transport
    //   theta              0.70, curvature of the light response of electron transport
    //                      (de Pury & Farquhar, 1997)
    // The other temperature responses are the Helios defaults.
    FarquharModelCoefficients photoparams;
    photoparams.Vcmax = r.Vcmax25;
    photoparams.Jmax  = r.Jmax25;
    photoparams.Rd      = r.rd25;
    photoparams.O       = 210.0f;
    photoparams.dH_Jmax = 43.9f;
    // alpha, theta and Tp are set with the value-only setters of FarquharModelCoefficients,
    // which make them independent of leaf temperature (value at 25 C, no activation energy).
    // The one-dimensional model treats them the same way.
    photoparams.setQuantumEfficiency_alpha(0.385f);
    photoparams.setLightResponseCurvature_theta(0.70f);
    photoparams.setTPU(r.tp25);

    photo.setModelCoefficients(photoparams);
    photo.setModelType_Farquhar();

    // Vcmax25 profile (Wang et al., 2026; Methods S1.4). With relative height
    // l = (z - z_min)/(z_max - z_min) - 1 (-1 at the lowest element, 0 at the highest),
    // Vcmax25(l) = Vcmax25(top) x exp(0.64 l). Jmax25 is the same for every element.
    std::vector<FarquharModelCoefficients> per_leaf_photoparams(leaf_UUIDs.size());
    std::vector<float> leaf_Vcmax(leaf_UUIDs.size(), 0.0f);
    for (size_t i = 0; i < leaf_UUIDs.size(); i++) {
        float l_wang = (leaf_z[i] - z_min) / z_range - 1.0f;
        float Vc_z = r.Vcmax25 * std::exp(K_VCMAX_PROFILE * l_wang);
        leaf_Vcmax[i] = Vc_z;
        per_leaf_photoparams[i] = photoparams;
        per_leaf_photoparams[i].Vcmax = Vc_z;
    }
    photo.setModelCoefficients(per_leaf_photoparams, leaf_UUIDs);

    // ============================================================
    // Atmospheric conditions (air temperature in K, relative humidity as a fraction)
    // ============================================================
    // Air temperature, humidity, wind speed and CO2 on every surface. Emissivity 0.95 for
    // leaves and ground in all bands. Surface temperatures start at air temperature.
    context.setPrimitiveData(all_UUIDs, "air_temperature", r.air_T_K);
    context.setPrimitiveData(all_UUIDs, "air_humidity", r.RH_fraction);
    context.setPrimitiveData(all_UUIDs, "wind_speed", r.wind_m_s);
    context.setPrimitiveData(all_UUIDs, "air_CO2", CO2_PPM);
    context.setPrimitiveData(leaf_UUIDs,   "emissivity_PAR", EMISS_LW);
    context.setPrimitiveData(leaf_UUIDs,   "emissivity_NIR", EMISS_LW);
    context.setPrimitiveData(leaf_UUIDs,   "emissivity_LW",  EMISS_LW);
    context.setPrimitiveData(ground_UUIDs, "emissivity_PAR", EMISS_LW);
    context.setPrimitiveData(ground_UUIDs, "emissivity_NIR", EMISS_LW);
    context.setPrimitiveData(ground_UUIDs, "emissivity_LW",  EMISS_LW);
    context.setPrimitiveData(all_UUIDs, "temperature", r.air_T_K);

    // Clear-sky incoming longwave, PAR and NIR and the diffuse fraction from the solar model
    // of the solarposition plugin (REST2; Gueymard, 2008), for the station pressure, air
    // temperature and humidity. The direct part of PAR and NIR goes to the sun source and the
    // diffuse part to the sky.
    float LW = solar.getAmbientLongwaveFlux(r.air_T_K, r.RH_fraction);
    float PAR_TOA = solar.getSolarFluxPAR(r.BP_Pa, r.air_T_K, r.RH_fraction, TURBIDITY);
    float NIR_TOA = solar.getSolarFluxNIR(r.BP_Pa, r.air_T_K, r.RH_fraction, TURBIDITY);
    float f_diff  = solar.getDiffuseFraction(r.BP_Pa, r.air_T_K, r.RH_fraction, TURBIDITY);

    radiation.setSourceFlux(sun, "PAR", PAR_TOA * (1.0f - f_diff));
    radiation.setDiffuseRadiationFlux("PAR", PAR_TOA * f_diff);
    radiation.setSourceFlux(sun, "NIR", NIR_TOA * (1.0f - f_diff));
    radiation.setDiffuseRadiationFlux("NIR", NIR_TOA * f_diff);
    radiation.setDiffuseRadiationFlux("LW", LW);
    radiation.setSourcePosition(sun, solar.getSunDirectionVector());

    // Two-pass solution (Methods S1.4). The first pass solves the boundary layer, all three
    // radiation bands, stomata and the energy balance with leaf surfaces at air temperature.
    // The second pass repeats longwave, stomata and the energy balance with the updated leaf
    // temperatures. Photosynthesis of each element is then computed.
    bl.run();
    radiation.runBand({"PAR","NIR","LW"});
    stomatal.run(leaf_UUIDs);
    eb.run();
    radiation.runBand("LW");
    stomatal.run(leaf_UUIDs);
    eb.run();
    photo.run(leaf_UUIDs);

    // ============================================================
    // Canopy totals
    // ============================================================
    // Absorbed PAR (W m-2 of element area) and net photosynthesis (umol m-2 s-1) of each
    // element are weighted by element area and divided by the 9 m2 of ground.
    float ground_area = cp.canopy_extent.x * cp.canopy_extent.y;
    float total_abs_PAR_W = 0.0f, total_A_umol = 0.0f;

    // Per-element output file, named by canopy and date (see the header).
    char fname[512];
    snprintf(fname, sizeof(fname), "%s/%s_DAP%03d.csv",
             per_leaf_dir.c_str(), r.Loc_ID.c_str(), r.DAP);
    std::ofstream perleaf(fname);
    perleaf << "UUID,z_m,leaf_area_m2,abs_PAR_W_m2,A_umol_m2_s,Vcmax_local\n";

    for (size_t i = 0; i < leaf_UUIDs.size(); i++) {
        uint UUID = leaf_UUIDs[i];
        float abs_PAR = 0.0f, A = 0.0f;
        context.getPrimitiveData(UUID, "radiation_flux_PAR", abs_PAR);
        context.getPrimitiveData(UUID, "net_photosynthesis", A);
        float leaf_area = context.getPrimitiveArea(UUID);
        total_abs_PAR_W += abs_PAR * leaf_area;
        total_A_umol    += A       * leaf_area;
        perleaf << UUID << "," << leaf_z[i] << "," << leaf_area << ","
                << abs_PAR << "," << A << "," << leaf_Vcmax[i] << "\n";
    }
    perleaf.close();

    // Canopy absorbed PAR (W m-2 and umol m-2 s-1), canopy A, fAPAR relative to the clear-sky
    // PAR of the run, canopy LUE (canopy A per absorbed photon) and canopy A per incident
    // photon.
    float canopy_abs_PAR_W = total_abs_PAR_W / ground_area;
    float canopy_abs_PAR_um = canopy_abs_PAR_W * PAR_W_TO_UMOL;
    float canopy_A = total_A_umol / ground_area;
    float incident_PAR_W = PAR_TOA;
    float frac_abs = canopy_abs_PAR_W / incident_PAR_W;
    float A_per_absPAR = canopy_A / canopy_abs_PAR_um;
    float A_per_incPAR = frac_abs * A_per_absPAR;

    std::cout << "  -> incident PAR=" << incident_PAR_W << " W/m2; "
              << "abs PAR=" << canopy_abs_PAR_W << " W/m2; "
              << "A_canopy=" << canopy_A << " umol CO2/m2/s; "
              << "frac_abs=" << frac_abs << "; A/abs_PAR=" << A_per_absPAR << std::endl;

    // ============================================================
    // Summary row
    // ============================================================
    // n_plots is 1 (one canopy per run). n_leaflets is the number of sub-leaf elements in the
    // canopy (NX x NY per leaflet). The last three columns give the sub-leaf grid.
    summary_out << r.Loc_ID << "," << r.Site << ","
                << r.Spacing << "," << r.Leaf_type << "," << r.DAP << ","
                << r.DOY << "," << r.date_iso << ",1,"
                << r.LAI << "," << r.height_m << ","
                << r.leaf_length_m << "," << r.leaf_avwidth_m << ","
                << r.Vcmax25 << "," << r.Jmax25 << "," << r.Vcmax_n << "," << r.Jmax_n << ","
                << r.air_T_C << "," << r.RH_fraction << "," << r.wind_m_s << "," << r.BP_Pa << ","
                << CO2_PPM << ","
                << incident_PAR_W << "," << canopy_abs_PAR_W << ","
                << canopy_A << "," << frac_abs << "," << A_per_absPAR << "," << A_per_incPAR << ","
                << leaf_UUIDs.size() << ","
                << g_N_sub_x << "," << g_N_sub_y << "," << (g_N_sub_x * g_N_sub_y)
                << "\n";
    summary_out.flush();
}

// ============================================================
// Main
// ============================================================
int main(int argc, char **argv) {
    // Arguments: site, row spacing code, leaflet type, DAP of the class-mean canopy, and the
    // sub-leaf grid NX and NY.
    if (argc != 7) {
        std::cerr << "Usage: " << argv[0]
                  << " <SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>\n"
                  << "  Mesh-test run: SITE in {EF,SF}, SPACING in {15,30},\n"
                  << "  LEAF_TYPE in {Broad,Narrow}, DAP = peak-LAI DAP per cell,\n"
                  << "  NX/NY = sub-leaf grid (e.g. 3 3 for production N_sub=9).\n"
                  << "Example: " << argv[0] << " EF 15 Broad 61 3 3\n";
        return 1;
    }
    std::string site      = argv[1];
    int         spacing   = std::atoi(argv[2]);
    std::string leaf_type = argv[3];
    int         dap       = std::atoi(argv[4]);
    g_N_sub_x             = std::atoi(argv[5]);
    g_N_sub_y             = std::atoi(argv[6]);
    // Canopy identifier, for example EF_15_Broad_DAP061 (the Loc_ID in the input file).
    char loc_id_buf[64];
    snprintf(loc_id_buf, sizeof(loc_id_buf), "%s_%d_%s_DAP%03d",
             site.c_str(), spacing, leaf_type.c_str(), dap);
    std::string loc_id = loc_id_buf;
    int use_cell_mean_vcmax = 0;  // the input rows already hold class-mean biochemistry

    if (site != "EF" && site != "SF") {
        std::cerr << "ERROR: site must be EF or SF; got '" << site << "'\n";
        return 1;
    }
    if (leaf_type != "Broad" && leaf_type != "Narrow") {
        std::cerr << "ERROR: leaf must be Broad or Narrow; got '" << leaf_type << "'\n";
        return 1;
    }

    std::cout << "Single-task run: site=" << site
              << " loc_id=" << loc_id
              << " spacing=" << spacing
              << " leaf=" << leaf_type
              << " DAP=" << dap << std::endl;

    // Output folders, relative to the working directory (build/).
    std::string out_dir      = "outputs/" + site;
    std::string per_leaf_dir = out_dir + "/per_leaf";
    std::string per_task_dir = out_dir + "/per_task";
    mkdir("outputs", 0755);
    mkdir(out_dir.c_str(), 0755);
    mkdir(per_leaf_dir.c_str(), 0755);
    mkdir(per_task_dir.c_str(), 0755);

    // Input file. The binary runs in build/, so ../inputs/ is the inputs folder of the
    // project (docs/cluster_run.md). The same file holds the eight class-mean canopies of
    // both sites and serves as the class-mean lookup.
    std::string per_plot_csv  = "../inputs/mesh_test_inputs.csv";
    std::string cell_mean_csv = per_plot_csv;

    std::cerr << "[DEBUG] reading per_plot_csv: " << per_plot_csv << std::endl;
    auto rows = read_per_plot_csv(per_plot_csv, site);
    std::cerr << "[DEBUG] read " << rows.size() << " rows from per_plot_csv" << std::endl;
    std::cerr << "[DEBUG] reading cell_mean_csv: " << cell_mean_csv << std::endl;
    auto cell_biochem = read_cell_biochem(cell_mean_csv);
    std::cerr << "[DEBUG] read " << cell_biochem.size() << " cells from cell_mean_csv" << std::endl;

    // Find the row of this canopy and date.
    std::vector<PlotDAP> filtered;
    for (auto &r : rows) {
        if (r.Loc_ID == loc_id && r.DAP == dap) {
            // Vcmax25 and Jmax25 of this task, handled as in helios_main.cpp. Every row of the
            // mesh-test inputs holds both values, so the run takes the branch that keeps them
            // and writes Vcmax_n = Jmax_n = 1.
            if (use_cell_mean_vcmax == 0 && r.Vcmax25 < 0.0f) {
                std::cerr << "ERROR: PRIMARY mode but per-plot Vcmax25 not measured for "
                          << loc_id << " (DAP " << dap << "). "
                          << "Vcmax25=" << r.Vcmax25 << ".\n"
                          << "  This plot should be excluded from the PRIMARY manifest. "
                          << "If you intended SENSITIVITY mode (cell-mean both), pass "
                          << "USE_CELL_MEAN_VCMAX=1.\n";
                return 1;
            }

            const bool sub_vcmax = (use_cell_mean_vcmax == 1);
            const bool sub_jmax  = (use_cell_mean_vcmax == 1 || r.Jmax25 < 0.0f);

            if (sub_vcmax || sub_jmax) {
                std::string key = std::to_string(r.Spacing) + "_" + r.Leaf_type;
                auto it = cell_biochem.find(key);
                if (it == cell_biochem.end()) {
                    std::cerr << "ERROR: no cell-mean biochem for key " << key << std::endl;
                    return 1;
                }
                if (sub_vcmax) {
                    r.Vcmax25 = it->second.Vcmax25_cell_mean;
                    r.Vcmax_n = it->second.Vcmax_n;
                } else {
                    r.Vcmax_n = 1;  // value of the input row
                }
                if (sub_jmax) {
                    r.Jmax25 = it->second.Jmax25_cell_mean;
                    r.Jmax_n = it->second.Jmax_n;
                } else {
                    r.Jmax_n = 1;  // value of the input row
                }
                std::cout << "  Vcmax mode: "
                          << (sub_vcmax ? "Vcmax cell-mean" : "Vcmax per-plot")
                          << " + "
                          << (sub_jmax  ? "Jmax cell-mean"  : "Jmax per-plot")
                          << " (key=" << key << ")" << std::endl;
            } else {
                // Both values come from the input row.
                r.Vcmax_n = 1;
                r.Jmax_n  = 1;
                std::cout << "  Vcmax mode: per-plot field-measured (Vcmax + Jmax)" << std::endl;
            }
            filtered.push_back(r);
            break;
        }
    }
    if (filtered.empty()) {
        std::cerr << "ERROR: no row matches " << loc_id << " DAP " << dap << std::endl;
        return 1;
    }

    // Each task writes its own one-row summary file, so parallel array tasks never write to
    // the same file. The canopy identifier already contains the DAP, so the file name adds
    // only the sub-leaf grid.
    char sumfile[512];
    snprintf(sumfile, sizeof(sumfile), "%s/canopy_summary_%s_N%dx%d.csv",
             per_task_dir.c_str(), loc_id.c_str(), g_N_sub_x, g_N_sub_y);
    std::ofstream summary(sumfile);
    summary << "Loc_ID,Site,Spacing,Leaf_type,DAP,DOY,date,n_plots,"
            << "LAI_used,height_m_used,leaf_length_m_used,leaf_avwidth_m_used,"
            << "Vcmax25_used,Jmax25_used,Vcmax_n,Jmax_n,"
            << "air_T_C_used,RH_fraction_used,wind_m_s_used,BP_Pa_used,CO2_ppm_used,"
            << "incident_PAR_W_m2,abs_PAR_W_m2,A_umol_m2_s,"
            << "frac_PAR_absorbed,inst_canopy_A_per_abs_PAR_umol_per_umol,"
            << "inst_canopy_A_per_incident_PAR_umol_per_umol,n_leaflets,N_sub_x,N_sub_y,N_sub_total\n";

    run_one_simulation(filtered[0], summary, per_leaf_dir);
    summary.close();

    std::cout << "Done. Output: " << sumfile << std::endl;
    return 0;
}
