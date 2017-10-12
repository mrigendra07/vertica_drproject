#!/bin/bash

_args=("$@")

[ ${#_args[@]} -ne 1 ] && { echo " Parameter error. Try \`bash $0 <job_id>\`"; exit 1; }

[ -f tmp/transfer_status/${_args[0]}.sts ] && rm -f tmp/transfer_status/${_args[0]}.sts
[ -f tmp/._locks/engine/${_args[0]}.lf ] &&  rm -f tmp/._locks/engine/${_args[0]}.lf

[ -f jobs/runningRequests/${_args[0]}.req ] && mv jobs/runningRequests/${_args[0]}.req jobs/gaveupRequests

echo "done"
