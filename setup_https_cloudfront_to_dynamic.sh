#!/bin/bash -ex
if [ "$4" == "" ]; then
  echo 1>&2 "1st arg: SSL domain (e.g. basicruby.com)"
  echo 1>&2 "2nd arg: backend domain (e.g. digitalocean.basicruby.com)"
  echo 1>&2 "3rd arg: piwik domain (e.g. piwik.basicruby.com)"
  echo 1>&2 "4th arg: HTTP port on backend (e.g. 80)"
  exit 1
fi
DOMAIN=$1
BACKEND_DOMAIN=$2
PIWIK_DOMAIN=$3
HTTP_PORT=$4

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
    "Quantity": 2,
    "Items": [
      {
        "Id": "Custom1-$BACKEND_DOMAIN",
        "DomainName": "$BACKEND_DOMAIN",
        "CustomOriginConfig": {
          "HTTPPort": $HTTP_PORT,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 3,
            "Items": ["TLSv1", "TLSv1.1", "TLSv1.2"]
          }
        },
        "CustomHeaders": {
          "Quantity": 0,
          "Items": []
        },
        "OriginPath": ""
      },
      {
        "OriginPath": "",
        "CustomOriginConfig": {
          "OriginProtocolPolicy": "http-only",
          "HTTPPort": $HTTP_PORT,
          "OriginSslProtocols": {
            "Items": [
              "TLSv1",
              "TLSv1.1",
              "TLSv1.2"
            ],
            "Quantity": 3
          },
          "HTTPSPort": 443
        },
        "CustomHeaders": {
          "Quantity": 0
        },
        "Id": "Custom2-$PIWIK_DOMAIN",
        "DomainName": "$PIWIK_DOMAIN"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "Custom1-$BACKEND_DOMAIN",
    "ForwardedValues": {
      "QueryString": true,
      "Cookies": {
        "Forward": "all"
      },
      "Headers": {
        "Quantity": 0,
        "Items": []
      }
    },
    "ViewerProtocolPolicy": "redirect-to-https",
    "MinTTL": 0,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "SmoothStreaming": false,
    "DefaultTTL": 0,
    "MaxTTL": 31536000,
    "Compress": false,
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
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
    "Prefix": "$DOMAIN/"
  },
  "DefaultRootObject": "",
  "WebACLId": "",
  "CacheBehaviors": {
    "Quantity": 1,
    "Items": [
      {
        "TargetOriginId": "Custom2-$PIWIK_DOMAIN",
        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
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
        "PathPattern": "/piwik*",
        "Compress": false,
        "AllowedMethods": {
          "Quantity": 7,
          "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
          "CachedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
          }
        }
      }
    ]
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
