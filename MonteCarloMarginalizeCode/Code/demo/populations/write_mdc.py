#! /usr/bin/env python

import numpy as np
import argparse
import configparser
import h5py
from astropy.cosmology import Planck15
import lal
import lalsimulation as lalsim
import RIFT.lalsimutils as lalsimutils
from ligo.lw import lsctables, table, utils


def load_hdf5_events(param_file, dataset_name="events"):
    """
    Load MDC parameters from an HDF5 structured dataset.

    Expected default dataset: 'events'
    Available in the provided file format:
      - events
      - raw_events
      - indices
      - raw_indices
    """
    with h5py.File(param_file, "r") as f:
        if dataset_name not in f:
            available = list(f.keys())
            raise KeyError(
                f"Dataset '{dataset_name}' not found in {param_file}. "
                f"Available datasets: {available}"
            )

        data = f[dataset_name][()]

    if data.dtype.names is None:
        raise ValueError(
            f"Dataset '{dataset_name}' is not a structured array with named fields."
        )

    return data


def get_field(data, name):
    if name not in data.dtype.names:
        raise KeyError(f"Required field '{name}' not found in HDF5 dataset.")
    return np.asarray(data[name])


def redshift_to_luminosity_distance_mpc(redshift):
    """
    Convert redshift to luminosity distance in Mpc using Planck15 cosmology.
    """
    z = np.asarray(redshift, dtype=float)
    return Planck15.luminosity_distance(z).value


parser = argparse.ArgumentParser()
parser.add_argument(
    "--param-file",
    default=None,
    required=True,
    help="HDF5 population file with params to pass to PE",
)
parser.add_argument(
    "--ini-file",
    default=None,
    required=True,
    help="read standard ini file so inj and PE match",
)
parser.add_argument(
    "--hdf5-dataset",
    default="events",
    help="Structured HDF5 dataset to read (default: events)",
)
opts = parser.parse_args()

param_file = opts.param_file

config = configparser.ConfigParser(allow_no_value=True)
config.read(opts.ini_file)

# Fixed time/sky location
fix_sky_location = config.getboolean("priors", "fix_sky_location")
fix_event_time = config.getboolean("priors", "fix_event_time")
fiducial_ra = float(config.get("priors", "fiducial_ra"))
fiducial_dec = float(config.get("priors", "fiducial_dec"))
fiducial_event_time = float(config.get("priors", "fiducial_event_time"))

# Spin and eccentricity requests
no_spin = config.getboolean("priors", "no_spin")
precessing_spin = config.getboolean("priors", "precessing_spin")
aligned_spin = config.getboolean("priors", "aligned_spin")
use_eccentric = config.getboolean("priors", "use_eccentric")

# Noise/data requirements
ifos = ["H1", "L1", "V1"]
channels = {"H1": "FAKE-STRAIN", "L1": "FAKE-STRAIN", "V1": "FAKE-STRAIN"}
flow = {"H1": 20, "L1": 20, "V1": 20}

fmin_template = float(config.get("waveform", "fmin_template"))
fref = float(config.get("waveform", "fmin_template"))  # the same for now
fmax = float(config.get("data", "fmax"))
srate_data = float(config.get("data", "srate_data"))
seglen_data = float(config.get("data", "seglen_data"))
seglen_analysis = float(config.get("data", "seglen_analysis"))

# Approximant requests - TaylorF2Ecc requires extra (check rift_O4c for f_ecc???)
approx_str = config.get("waveform", "approx")
if "TaylorF2Ecc" in approx_str:
    set_fecc = 20.0
    amporder = -1
lmax = 4

# Read HDF5 structured dataset
read_vals = load_hdf5_events(param_file, dataset_name=opts.hdf5_dataset)
n_events = len(read_vals)

# Required columns in the provided HDF5 format
mass_1_source = get_field(read_vals, "mass_1_source")
mass_2_source = get_field(read_vals, "mass_2_source")
spin_1z = get_field(read_vals, "spin_1z")
spin_2z = get_field(read_vals, "spin_2z")
eccentricity = get_field(read_vals, "eccentricity")
mean_anomaly = get_field(read_vals, "mean_anomaly")
redshift = get_field(read_vals, "redshift")
ra = get_field(read_vals, "ra")
dec = get_field(read_vals, "dec")
detection_time = get_field(read_vals, "detection_time")
cos_iota = get_field(read_vals, "cos_iota")
psi = get_field(read_vals, "psi")
phi_orb = get_field(read_vals, "phi_orb")
luminosity_distance = get_field(read_vals, "luminosity_distance")
# The new HDF5 file does not store luminosity_distance directly, so compute it from redshift.
#luminosity_distance = redshift_to_luminosity_distance_mpc(redshift)

if precessing_spin:
    raise ValueError(
        "The provided HDF5 file only contains aligned-spin components "
        "(spin_1z, spin_2z). It does not contain spin_1x, spin_1y, spin_2x, spin_2y."
    )

# Create list of all waveforms to send to xml, like ish pp_RIFT
P_list = []
indx = 0
while len(P_list) < n_events:
    print("event ++{}".format(indx))
    P = lalsimutils.ChooseWaveformParams()

    P.tref = fiducial_event_time
    P.fmin = fmin_template
    P.fref = fref
    P.deltaF = 1.0 / seglen_data
    P.deltaT = 1.0 / srate_data

    # sky location
    if fix_sky_location:
        P.theta = fiducial_dec
        P.phi = fiducial_ra
    else:
        P.theta = ra[indx]
        P.phi = dec[indx]

    # spins
    if no_spin:
        P.s1x = P.s1y = P.s1z = 0.0
        P.s2x = P.s2y = P.s2z = 0.0
    elif aligned_spin:
        P.s1x = P.s1y = 0.0
        P.s2x = P.s2y = 0.0
        P.s1z = spin_1z[indx]
        P.s2z = spin_2z[indx]
    else:
        # Safe fallback for configurations where neither no_spin nor aligned_spin is set.
        P.s1x = P.s1y = 0.0
        P.s2x = P.s2y = 0.0
        P.s1z = spin_1z[indx]
        P.s2z = spin_2z[indx]

    P.approx = lalsim.GetApproximantFromString(approx_str)

    # Source-frame masses from HDF5
    P.m1 = mass_1_source[indx] * lal.MSUN_SI
    P.m2 = mass_2_source[indx] * lal.MSUN_SI

    if use_eccentric:
        P.eccentricity = eccentricity[indx]
        P.meanPerAno = mean_anomaly[indx]
    if "TaylorF2Ecc" in approx_str:
        P.ampO = amporder

    P.dist = luminosity_distance[indx] * 1e6 * lal.PC_SI
    P.phiref = phi_orb[indx]
    P.psi = psi[indx]
    P.incl = np.arccos(cos_iota[indx])

    # If event times should come from the file, use detection_time.
    if not fix_event_time:
        P.tref = detection_time[indx]

    P_list.append(P)
    indx += 1

lalsimutils.ChooseWaveformParams_array_to_xml(
    P_list, "mdc", fref=fmin_template, deltaF=1 / 16.0
)

