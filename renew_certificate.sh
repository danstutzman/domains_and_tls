#!/bin/bash -ex
cd `dirname $0`

if [ "$1" == "" ]; then
  echo 1>&2 "First arg should be domain (e.g. monitoring.danstutzman.com)"
  exit 1
fi
DOMAIN=$1

AWS_ACCESS_KEY_ID=`python -c "import json; print json.load(open('ssl_autorenewer.accesskey.json'))['AccessKey']['AccessKeyId']"`
AWS_SECRET_ACCESS_KEY=`python -c "import json; print json.load(open('ssl_autorenewer.accesskey.json'))['AccessKey']['SecretAccessKey']"`

bundle exec ruby -e"require 'aws-sdk'" || bundle install --path vendor/bundle
pushd tls/letsencrypt.sh

AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  ./letsencrypt.sh \
  --config ../letsencrypt_sh_config.sh \
  --cron --hook ../letsencrypt_sh_route53_hook.rb \
  --challenge dns-01 --domain $DOMAIN
pushd
