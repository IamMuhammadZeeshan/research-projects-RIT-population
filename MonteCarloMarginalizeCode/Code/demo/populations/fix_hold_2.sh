cd /home/muhammad.zeeshan/projects/research-projects-RIT/MonteCarloMarginalizeCode/Code/demo/populations/ecc_injections

find analysis_event_4 -type d \( -name "iteration_*_cip" -o -name "iteration_*_con" \) \
  -exec mkdir -p "{}/logs" \;
