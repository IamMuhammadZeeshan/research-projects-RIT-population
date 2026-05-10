#!/bin/bash

THRESHOLD=8

BASE_DIR="/home/muhammad.zeeshan/projects/active/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations"
SIGNAL_BASE="$BASE_DIR/ecc_injections/signal_frames"
COMBINED_BASE="$BASE_DIR/ecc_injections/combined_frames"
RUNDIRS_BASE="$BASE_DIR/ecc_injections/"

SNR_FILE="$BASE_DIR/snr_list.txt"
DEST_DIR="$BASE_DIR/ecc_injections/low_snr_events"

SIGNAL_DEST="$DEST_DIR/signal_frames"
COMBINED_DEST="$DEST_DIR/combined_frames"
RUNDIRS_DEST="$DEST_DIR"

mkdir -p "$SIGNAL_DEST" "$COMBINED_DEST" "$RUNDIRS_DEST"

awk -v thr="$THRESHOLD" '$2 < thr {print $1}' "$SNR_FILE" | while read -r filepath; do
    
    event_dir=$(dirname "$filepath")
    event_name=$(basename "$event_dir")
    rundir_name="analysis_$event_name"
    
    echo "Moving $event_name to low_snr_events..."
    
    # Move from signal_frames
    if [ -d "$SIGNAL_BASE/$event_name" ]; then
        echo "  signal_frames  : $SIGNAL_BASE/$event_name -> $SIGNAL_DEST/"
        mv "$SIGNAL_BASE/$event_name" "$SIGNAL_DEST/"
    fi

    # Move from combined_frames
    if [ -d "$COMBINED_BASE/$event_name" ]; then
        echo "  combined_frames: $COMBINED_BASE/$event_name -> $COMBINED_DEST/"
        mv "$COMBINED_BASE/$event_name" "$COMBINED_DEST/"
    fi

    # Move rundirs
    if [ -d "$RUNDIRS_BASE/$rundir_name" ]; then
        echo "  rundirs        : $RUNDIRS_BASE/$rundir_name -> $RUNDIRS_DEST/"
        mv "$RUNDIRS_BASE/$rundir_name" "$RUNDIRS_DEST/"
    fi

done
