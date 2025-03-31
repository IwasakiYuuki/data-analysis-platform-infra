#!/bin/bash
set -e

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 0
fi

if [ -z "$1" ]; then
  echo "Error: No environment specified"
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

if [ "$1" != "dev" ] && [ "$1" != "prod" ]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

ENV="$1"

ansible-playbook -i "inventories/$ENV/hosts" playbooks/install.yaml
ansible-playbook -i "inventories/$ENV/hosts" playbooks/setup.yaml

echo "All playbooks executed successfully."
