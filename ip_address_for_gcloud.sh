#!/bin/bash -e
if [ "$1" == "" ]; then
  echo 1>&2 "Arg 1: name of gcloud instance (e.g. gitlab)"
  exit 1
fi
INSTANCE_NAME=$1

gcloud compute instances list "$INSTANCE_NAME" --format flattened | grep natIP | awk '{print $2}'
