#!/bin/bash

# exit 0 when node in master state
# exit 1 when node in replica state

patroni_node_state=$(curl -s http://127.0.0.1:8008/leader | jq -r '.role')

function compare_vip_state_with_patroni_role() {
    if [[ "${patroni_node_state}" == "master" ]]; then
      exit 0
    else
      exit 1
    fi
}

function main() {
    compare_vip_state_with_patroni_role
}

main
