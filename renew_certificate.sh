#!/bin/bash -ex
if [ "$1" == "" ]; then
  echo 1>&2 "First arg should be domain (e.g. monitoring.danstutzman.com)"
  exit 1
fi
DOMAIN=$1

ruby -raws-sdk -eputs || sudo gem install aws-sdk
pushd tls/letsencrypt.sh
AWS_ACCESS_KEY_ID=`grep aws_access_key_id ~/.aws/config | awk '{print $3}'`
AWS_SECRET_ACCESS_KEY=`grep aws_secret_access_key ~/.aws/config | awk '{print $3}'`
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  ./letsencrypt.sh \
  --config ../letsencrypt_sh_config.sh \
  --cron --hook ../letsencrypt_sh_route53_hook.rb \
  --challenge dns-01 --domain $DOMAIN
pushd
