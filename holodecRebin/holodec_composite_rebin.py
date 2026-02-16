#!/usr/bin/python
# Above command must be placed on the first line, allowing use of command line arguments

# How to use this script:
# python3 scriptname.py RF##

# also create array for minimum diameter, and mean diameter
# possibilities: if spherical use mean diameter, if nonspherical use something else 


# For the given research flight
# Create a netcdf of composite DSD
# The dimensions will be
# time, roundness, diameter
# So, at each timestep, there will be circularity categories:
# circ_thresholds=[0.0, 0.5, 0.6, 0.7, 0.8, 0.9]
# Each circularity will have an associated DSD

# Required Python Libraries
import sys                  # Command line arguments
from netCDF4 import Dataset # Reading and writing netcdf files
import numpy as np          # Matrix and math operations
import csv                  # Read and write csv files
import datetime
from netCDF4 import num2date, date2num, date2index
import matplotlib.pyplot as plt
import xarray as xr

# Verify that the correct number of input arguments is provided
n_inputs = len(sys.argv) # Number of commandline inputs
if n_inputs != 2:
    print("Incorrect number of input arguments. \nExample usage:")
    print("python3 scriptname.py RF##")
    sys.exit(0)

# Verify that the correct files are being read and written
flightnumbers = ["RF01","RF02","RF05","RF06","RF07","RF09","RF10"]

flightnumber = sys.argv[1]
print("Flight: " + flightnumber)

#################################
# Read in the Holodec Data     #
# ################################
holo_nc = '/home/utest/Research/CAESAR/CAESAR_Data/holodec_EOL/'+flightnumber+'_holo.nc';
new_nc = flightnumber+'_holo_composite.nc'

h = Dataset(holo_nc, "r+", format="NETCDF4") # Open the netcdf file

h_times = np.array(h['time'])
holo_volume = 13.65*10**(-6) # m3

holo_binedges = [1.93, 2.91, 3.89, 4.87, 5.85, 6.83, 7.81, 8.79, 9.77, 10.75, \
                 11.73, 12.71, 13.69, 15.65, 17.61, 19.57, 21.53, 23.49, 25.45, \
                 27.41, 29.37, 31.34, 33.3, 35.26, 37.22, 39.18, 41.14, 43.1, \
                 45.00, 55.0, 65.0, 75.0, 85.0, \
                 95.0, 105.0, 125.0, 145.0, 175.0, 225.0, 275.0, 325.0, \
                 400.0, 475.0, 550.0, 625.0, 700.0,  825.0,  975.0,  1125.0, \
                 1275.0,  1425.0,  1575.0,  1725.0,  1875.0]
holo_bincenter = []
holo_bw = []

for i,e in enumerate(holo_binedges[:-1]):
    bw = holo_binedges[i+1]-e
    bincenter = e+(bw/2)
    holo_bw.append(bw * 10**(-6)) #m
    holo_bincenter.append(bincenter)

holo_bw = np.array(holo_bw)
holo_bincenter = np.array(holo_bincenter)
holo_ptime = np.array(h['particletime'])
holo_asprat = h['aspectratio']
holo_circ = h['arearatio']
holo_dmaj = np.array(h['dmajor'])
holo_dmin = np.array(h['dminor'])
holo_dmean = np.mean(np.array([holo_dmaj, holo_dmin]), axis=0)
n_samples = np.array(h['nholograms'])
holo_nt = np.array(h['nt'])
holo_id = np.array(h['hid'])

# Create composite diameter value where mean is used for small particles <45um and major is used for large particles >=45um
holo_dcomposite = np.empty_like(holo_dmean)
for p,d in enumerate(holo_dmean):
	if d < 45.0 and holo_asprat[p] > 0.5:
		holo_dcomposite[p] = d
	else:
		holo_dcomposite[p] = holo_dmaj[p]
	
print("number of holograms that had a particle in the volume", len(np.unique(holo_id)))
print("number of dropelts", len(holo_ptime))

circ_thresholds = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9]
circ_bounds = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

# Create array for roundness filered distribution
conc_round_dmaj = np.zeros((6, len(holo_bincenter),len(h_times)))
conc_round_dmean = np.zeros((6, len(holo_bincenter),len(h_times)))
conc_round_composite = np.zeros((6, len(holo_bincenter),len(h_times)))

# To get concentration: 
# Each 1Hz timestep, count how many ROUND droplets in each size bin

# prep particle times to be timed to 1Hz
# Aaron uses floor in his processing, not rounding to nearest integer
ptime_int = np.floor(holo_ptime)
int_test = np.unique(ptime_int)

nt_check = np.zeros(len(h_times))

# Create array for roundness filered number concentration
nt_round = np.zeros((6, len(h_times)))

## Fill the 3d concentration array
for i,t in enumerate(h_times):
    mask = (ptime_int == t)
    # To get concentration, divide by nholograms*volume
    # Volume is in the global attributes of EOL files
    if (sum(mask)>0):
    	if n_samples[i]==0:
    		conc_round_dmean[:,:,i] = np.nan
    		conc_round_dmaj[:,:,i] = np.nan
    		conc_round_composite[:,:,i] = np.nan  		
    	else:	
		    nt_check[i] = np.sum(mask)/(n_samples[i]*13.65*10**(-6)) #m3
		    
		    hist_dmaj, edges = np.histogramdd(
		        sample=[holo_circ[mask], holo_dmaj[mask]],
		        bins=[circ_bounds, holo_binedges]
		    )   
		    hist_dmaj = hist_dmaj/(n_samples[i]*13.65*10**(-6)) #m3
		    hist_dmaj = hist_dmaj / holo_bw[np.newaxis,:] #m4
		    conc_round_dmaj[:,:,i] = hist_dmaj

		    hist_dmean, edges = np.histogramdd(
		        sample=[holo_circ[mask], holo_dmean[mask]],
		        bins=[circ_bounds, holo_binedges]
		    )   
		    hist_dmean = hist_dmean/(n_samples[i]*13.65*10**(-6)) #m3
		    hist_dmean = hist_dmean / holo_bw[np.newaxis,:] #m4
		    conc_round_dmean[:,:,i] = hist_dmean
		    
		    hist_composite, edges = np.histogramdd(
		        sample=[holo_circ[mask], holo_dcomposite[mask]],
		        bins=[circ_bounds, holo_binedges]
		    )   
		    hist_composite = hist_composite/(n_samples[i]*13.65*10**(-6)) #m3
		    hist_composite = hist_composite / holo_bw[np.newaxis,:] #m4
		    conc_round_composite[:,:,i] = hist_composite
		    
		    nt_hist, nt_edges = np.histogram(holo_circ[mask], bins=circ_bounds)
		    nt_round[:,i] = nt_hist/(n_samples[i]*13.65*10**(-6)) #m3

print("num conc check", np.sum(nt_check==holo_nt))

# Open a new NetCDF file in write mode
new_ds = Dataset(new_nc, 'w', format='NETCDF4')
# Copy dimensions from the source file to the new file
for dim_name, dim in h.dimensions.items():
    if (dim_name=='time'):
        print (dim_name)
        new_ds.createDimension(dim_name, len(dim))

# Add the curcularity dimension, new bins
new_ds.createDimension("circularity", 6)
new_ds.createDimension("bin_edges", len(holo_binedges))
new_ds.createDimension("bin_centers", len(holo_bincenter))
# You can now create variables in 'new_ds' using these dimensions
# For example, to create a variable 'temperature' with dimensions 'time', 'lat', 'lon':
new_ds.createVariable('time', 'double', ('time'))
new_ds.variables['time'][:] = h['time'][:]
new_ds.createVariable('circularity', 'double', ('circularity'))
new_ds.variables['circularity'][:] = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9]
new_ds.createVariable('bin_edges', 'double', ('bin_edges'))
new_ds.variables['bin_edges'][:] = holo_binedges
new_ds.createVariable('bin_centers', 'double', ('bin_centers'))
new_ds.variables['bin_centers'][:] = holo_bincenter
new_ds.createVariable('concentration_dmajor', 'double', ('circularity','bin_centers','time'))
new_ds.variables['concentration_dmajor'][:,:,:] = conc_round_dmaj
new_ds.createVariable('concentration_dmean', 'double', ('circularity','bin_centers','time'))
new_ds.variables['concentration_dmean'][:,:,:] = conc_round_dmean
new_ds.createVariable('concentration_composite', 'double', ('circularity','bin_centers','time'))
new_ds.variables['concentration_composite'][:,:,:] = conc_round_composite
new_ds.createVariable('circularity_nt', 'double', ('circularity','time'))
new_ds.variables['circularity_nt'][:,:] = nt_round
new_ds.createVariable('nt', 'double', ('time'))
new_ds.variables['nt'][:] = h['nt'][:]

new_ds.close()
h.close()
