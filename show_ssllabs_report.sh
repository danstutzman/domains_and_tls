#!/bin/bash -ex
if [ "$1" == "" ]; then
  echo 1>&2 "First arg should be apex domain (e.g. basicruby.com)"
  exit 1
fi
DOMAIN=$1

open "https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN&hideResults=on&latest"
