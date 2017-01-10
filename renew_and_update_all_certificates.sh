#!/bin/bash -e

./delete_unused_certs.sh

./renew_certificate.sh vocabincontext.com
./setup_https_cloudfront_to_dynamic.sh \
  vocabincontext.com digitalocean.vocabincontext.com piwik.vocabincontext.com
./renew_certificate.sh basicruby.com
./setup_https_cloudfront_to_dynamic.sh \
  basicruby.com digitalocean.basicruby.com piwik.basicruby.com
./renew_certificate.sh danstutzman.com
./setup_https_cloudfront_to_s3.sh danstutzman.com danstutzman.com

./renew_certificate.sh grafana.monitoring.danstutzman.com
./renew_certificate.sh piwik.monitoring.danstutzman.com
./setup_https_cloudfront_to_dynamic.sh \
  danstutzman.com grafana.monitoring.danstutzman.com grafana.monitoring.danstutzman.com
