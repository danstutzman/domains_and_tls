#!/bin/bash -ex
if [ "$1" == "" ]; then
  echo 1>&2 "First arg should be apex domain (e.g. danstutzman.com)"
  exit 1
fi
DOMAIN=$1
if [ "$2" == "" ]; then
  echo 1>&2 "Second arg should be S3 bucket name (e.g. danstutzman.com)"
  exit 1
fi
BUCKET_NAME=$2

TIMESTAMP=`date -u +%Y-%m-%d-%H-%M-%S`
aws iam upload-server-certificate \
  --server-certificate-name $DOMAIN-$TIMESTAMP \
  --certificate-body file://tls/certs/$DOMAIN/cert.pem \
  --private-key file://tls/certs/$DOMAIN/privkey.pem \
  --certificate-chain file://tls/certs/$DOMAIN/chain.pem \
  --path /cloudfront/ \
  | tee upload-server-certificate.json
SERVER_CERTIFICATE_ID=`cat upload-server-certificate.json | python -c "import json,sys; response = json.load(sys.stdin); print response['ServerCertificateMetadata']['ServerCertificateId']"`
rm upload-server-certificate.json

aws configure set preview.cloudfront true

cat > distconfig.json <<EOF
{
  "CallerReference": "$DOMAIN",
  "Origins": {
      "Items": [
          {
              "S3OriginConfig": {
                  "OriginAccessIdentity": ""
              },
              "OriginPath": "",
              "CustomHeaders": {
                  "Quantity": 0
              },
              "Id": "S3-$BUCKET_NAME",
              "DomainName": "$BUCKET_NAME.s3.amazonaws.com"
          }
      ],
      "Quantity": 1
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      },
      "Headers": {
        "Quantity": 0,
        "Items": []
      }
    },
    "ViewerProtocolPolicy": "allow-all",
    "MinTTL": 0,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "SmoothStreaming": false,
    "DefaultTTL": 0,
    "MaxTTL": 31536000,
    "Compress": true,
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    }
  },
  "Comment": "$DOMAIN",
  "Enabled": true,

  "PriceClass": "PriceClass_All",
  "Aliases": {
    "Quantity": 1,
    "Items": ["$DOMAIN"]
  },
  "Logging": {
    "Enabled": true,
    "IncludeCookies": false,
    "Bucket": "cloudfront-logs-danstutzman.s3.amazonaws.com",
    "Prefix": ""
  },
  "DefaultRootObject": "",
  "WebACLId": "",
  "CacheBehaviors": {
    "Quantity": 0,
    "Items": []
  },
  "CustomErrorResponses": {
    "Quantity": 0,
    "Items": []
  },
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": false,
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1",
    "Certificate": "$SERVER_CERTIFICATE_ID",
    "IAMCertificateId": "$SERVER_CERTIFICATE_ID",
    "CertificateSource": "iam"
  },
  "Restrictions": {
    "GeoRestriction": {
      "RestrictionType": "none",
      "Quantity": 0,
      "Items": []
    }
  }
}
EOF

DISTRIBUTION_ID=`aws cloudfront list-distributions | python -c "import json,sys; distributions = json.load(sys.stdin); print '\n'.join([distribution['Id'] for distribution in distributions['DistributionList']['Items'] if distribution['Comment'] == '$DOMAIN'])"`

if [ "$DISTRIBUTION_ID" == "" ]; then
  aws cloudfront create-distribution --distribution-config file://distconfig.json
else
  DISTRIBUTION_ETAG=`aws cloudfront get-distribution --id "$DISTRIBUTION_ID" | python -c "import json,sys; response = json.load(sys.stdin); print response['ETag']"`
  aws cloudfront update-distribution --id "$DISTRIBUTION_ID" --distribution-config file://distconfig.json --if-match "$DISTRIBUTION_ETAG"
fi

rm -f distconfig.json
