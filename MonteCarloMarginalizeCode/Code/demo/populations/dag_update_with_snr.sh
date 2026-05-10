#!/bin/bash

THRESHOLD=8

BASE_DIR="/home/muhammad.zeeshan/projects/active/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations"
SNR_FILE="$BASE_DIR/snr_list.txt"
MASTER_DAG="$BASE_DIR/ecc_injections/master_clean.dag"

LOW_DAG="$BASE_DIR/ecc_injections/low_snr_events/master_clean_low_snr.dag"
HIGH_DAG="$BASE_DIR/ecc_injections/master_clean_high_snr.dag"

TMP_LOW_EVENTS=$(mktemp)
low=$(awk -v thr="$THRESHOLD" '$2 < thr {count++} END {print count+0}' "$SNR_FILE")

total=$(awk 'END {print NR}' "$SNR_FILE")

high=$((total - low))

echo "Total events     : $total"

echo "Low SNR events   : $low  (SNR < $THRESHOLD)"

echo "High SNR events  : $high (SNR >= $THRESHOLD)"
# Start fresh
> "$LOW_DAG"
> "$HIGH_DAG"

# Build list of low-SNR event names in the same style as the DAG uses
awk -v thr="$THRESHOLD" '
$2 < thr {
    path = $1
    n = split(path, a, "/")

    # Usually path ends with a filename, so event dir is a[n-1]
    event = a[n-1]

    # Store as analysis_event_###
    print "analysis_" event
}
' "$SNR_FILE" | sort -u > "$TMP_LOW_EVENTS"

#echo "Low-SNR events found:"
#cat "$TMP_LOW_EVENTS"
#echo

# Split DAG line by line
while IFS= read -r line; do
    event=$(echo "$line" | grep -oE 'analysis_event_[0-9]+')

    if [ -n "$event" ]; then
        if grep -qx "$event" "$TMP_LOW_EVENTS"; then
            echo "$line" >> "$LOW_DAG"
        else
            echo "$line" >> "$HIGH_DAG"
        fi
    else
        # If line has no event tag, keep it in high file by default
        echo "$line" >> "$HIGH_DAG"
    fi
done < "$MASTER_DAG"

rm -f "$TMP_LOW_EVENTS"

echo "Created:"
echo "  $LOW_DAG"
echo "  $HIGH_DAG"
