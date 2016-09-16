#!/bin/bash -e
if [ "$1" == "" ]; then
  echo 1>&2 "Arg 1: name of digitalocean droplet (e.g. basicruby)"
  exit 1
fi
DROPLET_NAME=$1

tugboat droplets | grep "$DROPLET_NAME " | egrep -oh "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" || true
