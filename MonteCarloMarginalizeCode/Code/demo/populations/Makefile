SHELL := /bin/bash
PWD := $(shell pwd)
ENV_NAME := rift-gwkokab
USER := muhammad.zeeshan

# note this MUST match dirname in your ini file
RUNDIR := $(PWD)/ecc_injections
PARAM_FILE := $(PWD)/synthetic_events.hdf5
INI_FILE := /home/$(USER)/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/pop-example.ini

WRITE_MDC := /home/$(USER)/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/write_mdc.py

CONDA_SH := /cvmfs/software.igwn.org/conda/etc/profile.d/conda.sh
BASE_ENV := /cvmfs/software.igwn.org/conda/envs/igwn-py310
TARGET_ENV := /home/$(USER)/.conda/envs/$(ENV_NAME)

SRC_DIR := /home/$(USER)/src
REPO_DIR := $(SRC_DIR)/research-projects-RIT
PP_RIFT_DIR := $(REPO_DIR)/MonteCarloMarginalizeCode/Code/test/pp

SETUP_SH := $(PWD)/setup.sh

.PHONY: setup-env injections rundir submit

setup-env:
		source "$(CONDA_SH)" && \
		if [ ! -d "$(TARGET_ENV)" ]; then \
			mamba create --yes --clone "$(BASE_ENV)" --prefix "$(TARGET_ENV)"; \
		fi && \
		conda activate "$(TARGET_ENV)" && \
		mkdir -p "$(SRC_DIR)" && \
		cd "$(SRC_DIR)" && \
		if [ ! -d research-projects-RIT ]; then \
			git clone https://github.com/oshaughn/research-projects-RIT.git; \
		fi && \
		cd research-projects-RIT && \
		git fetch --all && \
		git checkout rift_O4d && \
		pip install -e . && \
		pip install --upgrade scipy && \
		pip install --upgrade pyseobnr && \
		pip install numpy==1.24.4

injections:
	    source "$(CONDA_SH)" && \
		conda activate "$(TARGET_ENV)" && \
		mkdir -p "$(RUNDIR)" && \
		cd "$(RUNDIR)" && \
		python "$(WRITE_MDC)" --param-file "$(PARAM_FILE)" --ini-file "$(INI_FILE)"

rundir:
		source "$(CONDA_SH)" && \
		conda activate "$(TARGET_ENV)" && \
		export PATH="$$PATH:$(PP_RIFT_DIR)" && \
		source "$(SETUP_SH)" && \
		which pp_RIFT_with_ini && \
		pp_RIFT_with_ini --use-ini "$(INI_FILE)" --add-extrinsic --use-gwsignal --use-osg

submit:
		source "$(CONDA_SH)" && \
		conda activate "$(TARGET_ENV)" && \
		cd "$(RUNDIR)" && \
		condor_submit_dag -import_env master_clean_high_snr.dag
