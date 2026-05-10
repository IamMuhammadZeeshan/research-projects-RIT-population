#!/bin/bash

# Base directories
BASE_DIR="/home/muhammad.zeeshan/projects/active/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations"
SIGNAL_DIR="$BASE_DIR/ecc_injections/signal_frames"
PSD_DIR="$BASE_DIR/psds/rundir_psds"

# PSD files
H1_PSD="$PSD_DIR/H1-psd.xml.gz"
L1_PSD="$PSD_DIR/L1-psd.xml.gz"
V1_PSD="$PSD_DIR/V1-psd.xml.gz"

# Loop over events
for event_dir in "$SIGNAL_DIR"/event_*; do
    (
        cd "$event_dir" || exit

        util_FrameZeroNoiseSNR.py \
            --cache signals.cache \
            --psd-file H1="$H1_PSD" \
            --psd-file L1="$L1_PSD" \
            --psd-file V1="$V1_PSD"
    )
done

for i in $SIGNAL_DIR/event_*/snr*.txt; do
    echo "$i $(awk '{print $NF}' "$i" | tr '}' ' ')"
done | sort -k2 -nr > snr_list.txt
