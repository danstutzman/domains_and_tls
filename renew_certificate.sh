#!/bin/bash -e
cd `dirname $0`

if [ "$1" == "" ]; then
  echo 1>&2 "First arg should be domain (e.g. monitoring.danstutzman.com)"
  exit 1
fi
DOMAIN=$1

AWS_ACCESS_KEY_ID=`grep aws_access_key_id ~/.aws/config | awk '{print $3}'`
AWS_SECRET_ACCESS_KEY=`grep aws_secret_access_key ~/.aws/config | awk '{print $3}'`

bundle exec ruby -e"require 'aws-sdk'" || bundle install --path vendor/bundle
pushd tls/letsencrypt.sh

AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  ./letsencrypt.sh \
  --config ../letsencrypt_sh_config.sh \
  --cron --hook ../letsencrypt_sh_route53_hook.rb \
  --challenge dns-01 --domain $DOMAIN
pushd
