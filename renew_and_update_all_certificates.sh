#!/bin/bash -ex

for CERT_NAME in `aws iam list-server-certificates | python -c "import json, sys; print '\n'.join([cert['ServerCertificateName'] for cert in json.load(sys.stdin)['ServerCertificateMetadataList']])"`; do
  aws iam delete-server-certificate --server-certificate-name $CERT_NAME || true
done

./renew_certificate.sh vocabincontext.com
./setup_https_cloudfront_to_dynamic.sh \
  vocabincontext.com digitalocean.vocabincontext.com piwik.vocabincontext.com
./renew_certificate.sh basicruby.com
./setup_https_cloudfront_to_dynamic.sh \
  basicruby.com digitalocean.basicruby.com piwik.basicruby.com
./renew_certificate.sh danstutzman.com
./setup_https_cloudfront_to_s3.sh danstutzman.com danstutzman.com
