#!/bin/bash -e

# Try to delete all server certificates.  The ones that are in use will give a
# DeleteConflict message, which we can ignore
echo "aws iam list-server-certificates"
for CERT_NAME in `aws iam list-server-certificates | python -c "import json, sys; print '\n'.join([cert['ServerCertificateName'] for cert in json.load(sys.stdin)['ServerCertificateMetadataList']])"`; do
  echo "aws iam delete-server-certificate --server-certificate-name $CERT_NAME"
  set +e
  OUTPUT=`aws iam delete-server-certificate --server-certificate-name $CERT_NAME 2>&1`
  ERROR=$?
  set -e
  if [ $ERROR != 0 ]; then
    case "$OUTPUT" in
      *DeleteConflict*) ;; # It won't let us delete certificates that are in use
      *) echo 1>&2 "$ERROR from delete-server-certificate: $OUTPUT"; exit 1;;
    esac
  fi
done

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
