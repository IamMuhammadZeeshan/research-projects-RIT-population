# Generating Mock Compact Binary Events with GWKokab and Producing Realistic PEs with RIFT

This tutorial describes a **complete, reproducible workflow** for:

1. Generating mock compact-binary injections using **GWKokab**.  
2. Producing realistic **parameter estimates (PEs)** for those injections using **RIFT**.

To avoid dependency and version conflicts, **GWKokab and RIFT must be installed in separate conda environments**.

---

## Overview of the Workflow

This tutorial follows the pipeline below:

1. Set up and validate **GWKokab**
2. Configure the **Makefile** and `pop-example.ini`
3. Create the **RIFT** environment
4. Convert GWKokab injections into RIFT-readable format
5. Create RIFT run directories, signal frames, and combined frames
6. Compute SNR and filter low-SNR events
7. Run a final pre-submission checklist
8. Submit PE jobs
9. Plot results and run diagnostics
10. Collect PE files for population inference

## Step 0 — Set Up GWKokab

Please see the GWKokab documentation (https://github.com/kokabsc/gwkokab) for instructions on generating mock injections, fake posteriors, and delta-error realizations.

Before proceeding to RIFT, verify that GWKokab can recover the injected population hyperparameters using either delta-error realizations or fake posteriors.

Only proceed once this step works correctly.

## Step 2 — Configure the Makefile

RIFT uses a different software stack and must be installed in a separate conda environment.
Before running any RIFT commands, update the required variables in the `Makefile`, including the environment name, usernames, repository names, file names, and absolute paths.

```bash
ENV_NAME=rift-gwkokab
USER = muhammad.zeeshan

# Must match the run directory specified in the ini file
RUNDIR     = '${PWD}/ecc_injections'
PARAM_FILE = '${PWD}/synthetic_events.hdf5'
INI_FILE   = '${PWD}/pop-example.ini'
```
All user-defined analysis options must be set in `pop-example.ini`. This includes whether the run is non-spinning, aligned-spin, precessing-spin, circular, or eccentric, as well as the waveform approximant and all prior settings.

```bash
[pp]
n_events=155
working_directory=ecc_injections
test_convergence=True

[priors]
mc_min=4.35
mc_max=43.5
m_min=5.0
eta_min=0.08
eta_max=0.24999
... spin, eccentricity, redshift etc ...
```

Important:
- The value of `n_events` must match the number of events in `synthetic_events.hdf5`.
- All prior ranges in `pop-example.ini` must exactly match the ranges used to generate `synthetic_events.hdf5` with GWKokab.
- If priors do not match the injections, the resulting parameter estimates will be biased.
- Also update the noise-frame paths and username in `pop-example.ini` where needed.

## Step 3 — Create the RIFT Environment
```bash
make setup-env
```
This command:
- Creates the `rift-gwkokab` environment based on igwn-py310
- Clones the RIFT codebase
- Installs all required dependencies
- Enables eccentric waveform support (e.g. SEOBNRv5EHM)

Note: This setup assumes access to the LDG and the `igwn-py310` software stack.
## Step 4 — Prepare Injections for RIFT
Copy `synthetic_events.hdf5` from the GWKokab output directory into this RIFT repository, then run:
```bash
make injections
```
This command:
- Converts injections into RIFT-compatible format
- Generates `mdc.xml.gz` and saves it in `ecc_injections`
- Writes all outputs into the directory specified by `RUNDIR`

## Step 5 — Create RIFT Run Directories
Before running the following command, make sure the PSD paths are correct and that the number of noise frames is equal to or greater than the number of injections. 
```bash
make rundir
```
- It will generate signal and combined frames for each event
- Executes pp_RIFT_with_ini
- Creates production-style RIFT run directories

After the run directories are created, copy PSDs into each `rundir`, because each event requires its own PSD files:

```bash
for d in /home/muhammad.zeeshan/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/ecc_injections/analy*/rundir; do
  cp /home/muhammad.zeeshan/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/psds/rundir_psds/*psd.xml.gz "$d"
done
```

---

## Step 6 — Validate the Setup Before Submission

Before submitting expensive PE jobs, validate the setup carefully.

### 6.1 Verify Injection Consistency
- Ensure the number of events in `synthetic_events.hdf5` matches `n_events` in `pop-example.ini`.
- Make sure prior ranges in `[priors]` exactly match the injection ranges used in GWKokab.

⚠️ Mismatched priors will bias parameter-estimation results.

### 6.2 Check Noise Frames
- The number of noise frames must be **equal to or greater than** the number of injections.
- Each event should have a corresponding noise realization.
- You can generate your own or copy PSDs and noise frames on CIT. `/home/muhammad.zeeshan/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/psds`

### 6.3 Verify File Paths
Double-check paths in:
- `Makefile`
- `pop-example.ini`
- `write_mdc.py`

Incorrect paths are a common cause of silent failures.

### 6.4 Inspect Generated Outputs
For each event, make sure the workflow has created:
- signal frames
- combined frames
- `.gwf` strain files
- `.cache` files

### 6.5 Detect Empty Event Directories
Run:
```bash
find event_* -type d -empty
```
No event directory should be empty before proceeding.

### 6.6 Monitor Logs
While the workflow is running, monitor logs with:
```bash
tail -f nohup.out
```
Look for missing files, waveform failures, and path issues.

### 6.7 Confirm Physical Validity of Injections
Avoid injections with:
- extreme mass ratios
- very high eccentricity

These can lead to waveform failures, missing strain files, or empty combined-frame directories.

## Step 7 — Compute SNR and Filter Low-SNR Events

After generating signal frames, compute the SNR for each event using the `compute_snr.sh` and it will generate the `snr_list.txt`.

- Recommended threshold: **SNR > 10**
- Move low-SNR events into a separate directory such as `low_snr_events/` using `move_low_snr.sh`
- You may also want to separate `master_clean.dag` file for low and high SNR events using `dag_update_with_snr.sh`
- Only proceed with high-SNR events for PE runs

This reduces unnecessary computational cost.

## Step 8 — Final Pre-Submission Checklist

Before running `make submit`, confirm all of the following:

- No empty event directories:
```bash
find event_* -type d -empty
```
- Signal frames and combined frames exist for all events
- PSD files have been copied into each `rundir`
- Noise frames match or exceed the injection count
- All file paths are correct
- `nohup.out` shows no path or waveform errors

## Step 9 — Submit PE Jobs
```bash
make submit
```
This submits the PE production jobs. These runs may take days to complete, so monitor them with:
```bash
condor_q
condor_q -hold
condor_q -run
condor_rm -all
```
For additional information, use `condor -h`.
## Step 10 — Plotting Results and Diagnostics

RIFT provides automated plotting scripts that you can also use during runs to monitor progress.
- plot_iterationsAndSubdag_animation_with.sh
- plotme_anim_ecc.sh

To generate corner plots for all events:
```bash
plot_all.sh ./ecc_injections
```
## Additional Diagnostics and Common Issues
### Posterior Completion Check
```bash
for i in analysis_event_*; do
  echo $i $(ls $i/rundir/post*.dat $i/rundir/iter*cip/post*.dat 2>/dev/null | wc -l)
done
```
A completed run should contain `posterior_samples-4.dat`
## Step 11 — Gather PE Files for Population Inference
To perform population inference with GWKokab, gather the PE files from each `rundir` into a single folder by running:
```bash
./collect_all.sh
```
This collects the required file `extrinsic_posterior_samples.dat` from each `rundir` and saves the outputs in a folder called `collected_dat_files`.

Finally, run the following Python command to rename headers into the GWKokab-accepted format and optionally choose a random subset of PE samples per event:
```bash
python gwk_pop_conversion.py --input-dir ./collected_dat_files --output-dir ./rift_pes --n-rows 2000
```
Note: The latest GWKokab uses .h5 file format instead of .dat.


### Job Progress Tracking
```bash
condor_q -submitter muhammad.zeeshan -long -nobatch | grep Iwd | sort | uniq -c
```
### Likelihood Diagnostics
```bash
wc -l analysis_event_*/run*/con*.composite
```
and 
```bash
for i in an*/run*; do
  echo $i $(sort -rg -k11 $i/all.net | head -n 1 | awk '{print $11,$12,$10}')
done | sort -rg -k2
```
### Common Error: lal_path2cache
Error: FileNotFoundError: No such file or directory
Fix: remove .local folder in your home repo.
```bash
rm -rf ~/.local/bin/lal_path2cache` then rerun `make rundir
```

### Important Notes
- Always use absolute paths in RIFT configuration files.
- local.cache files must not be empty.
- Very loud events may take significantly longer to converge.
- Discard or re-run events that give a log-likelihood less than 5.
- If the corner-plot legend for an event iteration shows `F3`, it usually indicates a good completed run.
