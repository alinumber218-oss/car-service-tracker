#!/bin/bash
# Removes everything deployed by k8s-deploy-local.sh. Add -v to also delete
# PersistentVolumeClaims (wipes Postgres/MinIO data).
set -e

cd "$(dirname "$0")/.."

kubectl delete -k k8s/base --ignore-not-found

if [[ "$1" == "-v" ]]; then
  echo "Deleting PersistentVolumeClaims (this wipes stored data)..."
  kubectl delete pvc -n car-tracker --all --ignore-not-found
fi

echo "Done."
