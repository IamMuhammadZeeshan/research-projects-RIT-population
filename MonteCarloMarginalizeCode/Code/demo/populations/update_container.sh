#!/usr/bin/env bash
set -euo pipefail

OLD="rift_container_ros_seobnr_rift17p3.sif"
NEW="rift_container_ros_o4c-17.8rc10-20260410.sif"

BASE="/home/muhammad.zeeshan/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/ecc_injections"

find "$BASE"/analysis_event_*/rundir -name "ILE_extr.sub" -type f | while read -r file; do
    echo "Updating: $file"

    sed -i "s|$OLD|$NEW|g" "$file"
done

echo "All ILE_extr.sub files updated successfully."
