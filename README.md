# BETA version of microphysics data product. This dataset represents our best estimate of particle size distributions, by combining the data from four different cloud probes.

## Netcdf data structure:

netcdf RF01_microphysics_beta {
dimensions:
	time = 25065 ;
	bin_centers = 169 ;
	bin_edges = 170 ;
variables:
	double time(time) ;
		time:longname = "UTC time for concentration arrays and bulk variables" ;
		time:units = "Seconds from midnight of start date" ;
	double bin_edges(bin_edges) ;
		bin_edges:longname = "Upper/lower edges of concentration size bins" ;
		bin_edges:units = "microns" ;
	double bin_centers(bin_centers) ;
		bin_centers:longname = "Center value of concentration size bins" ;
		bin_centers:units = "microns" ;
	double concentration(bin_centers, time) ;
		concentration:longname = "Best estimate of particle number concentration, all particles, normalized by bin width" ;
		concentration:units = "#/m4" ;
	double concentration_err(bin_centers, time) ;
		concentration_err:longname = "Uncertainty bound on particle number concentration, all particles, normalized by bin width" ;
		concentration_err:units = "#/m4" ;
	double lat(time) ;
		lat:longname = "Latitude" ;
		lat:units = "degrees North" ;
	double lon(time) ;
		lon:longname = "Longitude" ;
		lon:units = "degrees East" ;
	double alt(time) ;
		alt:longname = "GPS Altitude" ;
		alt:units = "meters" ;
	double t(time) ;
		t:longname = "Ambient Temperature" ;
		t:units = "C" ;
	int cloud_phase(time) ;
		cloud_phase:longname = "Estimate of cloud phase identification using algorithm" ;
		cloud_phase:units = "none" ;
		cloud_phase:flag_values = 0, 1, 2, 3, 4 ;
		cloud_phase:flag_meaning = "clearicemixedliquiddrizzle" ;

// global attributes:
		:ProductName = "Cloud Microphysics Value-Added Data Product" ;
		:Version = "beta" ;
		:Source = "CDP, F2DS, HOLODEC, HVPS, Nevzorov" ;
		:DataContact = "Elise Rosky (emrosky@ucar.edu) or EOL Sarah Woods" ;
		:FlightDate = "02/28/2024" ;
		:ProjectName = "CAESAR" ;
		:Platform = "N130AR" ;
		:FlightNumber = "RF01" ;
		:date_created = "2026/02/16" ;
}


# RULES FOR COMBINING PROBE DATA FOR EACH TIMESTEP (ALL FLIGHTS):

## (create_bins.m) BIN EDGE DEFINITIONS:

probe_endbins.fixed_cdp =  [1.93  2.91  3.89  4.87  5.85  6.83  7.81  8.79  9.77 ...
   10.75 11.73 12.71];

probe_endbins.crossover_cdp_holo = [12.71 13.69 15.65 17.61];

probe_endbins.fixed_holo = [17.61 19.57 21.53 23.49 25.45 27.41 29.37 31.34 33.3  35.26 ...
   37.22 39.18 41.14 43.1  45.0];

- CDP can be used as backup if HOLODEC unavailable

probe_endbins.crossover_holo_f2ds = [ 45.  55.   65.   75.   85.   95. 105.  125.  ...
   145.  175.  225.];

probe_endbins.fixed_f2ds = [225. 275.  325.  400.  475.  550.  625.  700. 825.];

probe_endbins.crossover_f2ds_hvps = [825.  975.  1125.   1275.   1425.];

fixed.hvps = [1425… ];


- Fixed size ranges are size bins that always use the data from one specific probe, under any circumstance.-

- Crossover regions are size bins that will use a combination of values from two probes that overlap in that size range.

### Crossover regions:

(transition.m) If both probes have non-zero values for over half of the crossover region: 

- A mean of the two probes' values is taken when both probes are non-zero. If one probe=0 but the other has a value, the nonzero value is used. If both probes =0, then the value is zero.

- This preference for a nonzero value is used because probes with smaller sample volumes will produce zero concentration in size ranges where the second probe with a larger sample volume provides a measurement. Thus, it is preferred to use the non-zero value.

If probes do not both have values for over half of the regions:

- Only the probe with more non-zero values is used for the entire crossover region. This prevents a few outliers from producing jumps in the distribution.

### Uncertainty calculation: 
Error bars can be calculated for two probes that overlap within a size range. A fixed uncertainty for that timestep is calculated within the overlap region, and applied across the fill size range of both probes.

probe_endbins.overlap_cdp_holo = [ 15.65 17.61 19.57 21.53 23.49 25.45 27.41 29.37 31.34];
probe_endbins.overlap_holo_f2ds = [ 45. 55.   65.   75.   85.   95. 105.  125.  145.  175.  225. 275.  325.  400.];
probe_endbins.overlap_f2ds_hvps = [975.  1125.   1275.  1425.];

(calculate_uncertainty.m) Error is calculated as the mean of absolute difference between two probes within their overlap region: ONLY if over half the overlap region has two non-zero values (prevents a couple outliers from dominating the uncertainty values). Times where both probes equal zero are not used in the calculation (This would artificially reduce the error).

HVPS (or other counting probes) -> Uncertainty bar can be calculated based on square root of count number in bin. (Has not yet been implemented)

## ADDITIONAL OPERATIONS DONE TO PREPARE DATA:

### HOLODEC:
Holodec data is rebinned to transition smoothly between CDP and F2DS bins.
- See holo_composite_rebin.py in the holodecRebin folder.
- EOL archived holodec Netcdf files are used as input.
- Holodec mean diameter is used for particles with mean diameter < 45um and asprat>0.5, major diameter is used for mean diameter >=45um and any particle with asprat>0.5
Holodec 1Hz DSD’s are a 3 second boxcar average to increase particle statistics.
- See read_holo.m

### F2DS:
Processed using SODA release with DoF compactness implemented, and Korolev resizing (PSC) for particles up to 250 um (same Korolev resizing as the archived data).
F2DS bin edges [700.  800.  900. 1000. 1200. 1400. 1600. 1800. 2000.] are rebinned to [700.  825.  975.  1125.   1275.  1425.  1575.  1725.  1875.] to allow smooth transition with HVPS.
Concentrations are proportionally divided into the new bins.
- See read_f2ds.m

### CDP:
CDP bin edges [43.1  45.06 47.02 are rebinned to [43.1  45.00 47.02], to allow smooth transition with F2DS.
Concentrations are proportionally divided into the new bins.
- See read_cdp.m

