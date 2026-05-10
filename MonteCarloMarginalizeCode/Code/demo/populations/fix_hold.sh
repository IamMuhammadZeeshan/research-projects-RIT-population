#!/usr/bin/env bash
set -euo pipefail

SCHEDD="ldas-pcdev13.ligo.caltech.edu"

echo "Checking held jobs on schedd: $SCHEDD"

condor_q -name "$SCHEDD" -hold "$USER" \
  -af ClusterId ProcId HoldReason Iwd Args \
| grep "invalid interpreter" \
| while read -r line; do

    jobid=$(echo "$line" | awk '{print $1 "." $2}')

    rundir=$(echo "$line" | grep -oE '/home/[^ ]+/analysis_event_[0-9]+/rundir' | head -n 1)

    if [[ -z "${rundir}" ]]; then
        echo "Could not detect rundir for job $jobid"
        continue
    fi

    echo
    echo "Held job: $jobid"
    echo "Detected rundir: $rundir"

    found_sub=0

    while IFS= read -r subfile; do
        found_sub=1
        echo "Fixing submit file: $subfile"

        if grep -q 'TARGET.EPNFS=?=True' "$subfile"; then
            echo "Already fixed: $subfile"
        else
            cp "$subfile" "${subfile}.bak"

            sed -i \
              's/^requirements[[:space:]]*=[[:space:]]*/requirements = TARGET.EPNFS=?=True \&\& /' \
              "$subfile"
        fi
    done < <(find "$rundir" -type f -name "CIP*.sub")

    if [[ "$found_sub" -eq 0 ]]; then
        echo "No CIP*.sub files found under $rundir"
        continue
    fi

    echo "Releasing job: $jobid"
    condor_release -name "$SCHEDD" "$jobid"

done

echo
echo "Done. Check remaining held jobs with:"
echo "condor_q -name $SCHEDD -hold $USER"
