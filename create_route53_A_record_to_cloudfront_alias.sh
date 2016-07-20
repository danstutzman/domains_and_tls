#!/bin/bash -e
if [ "$1" == "" ]; then
  echo 1>&2 "First argument should be domain (e.g. basicruby.com)"
  exit 1
fi
DOMAIN=$1

CREATE_ZONE_OUTPUT=`aws route53 create-hosted-zone --name $DOMAIN --caller-reference $DOMAIN 2>&1 || true`
if [[ "$CREATE_ZONE_OUTPUT" != *HostedZoneAlreadyExists* ]]; then
  echo "$CREATE_ZONE_OUTPUT" 1>&2
  exit 1
fi

ZONE_ID=`aws route53 list-hosted-zones | python -c "
import json, sys
j=json.load(sys.stdin)
for zone in j['HostedZones']:
  if zone['Name'] == '$DOMAIN.':
    print zone['Id']
"`
if [ "$ZONE_ID" == "" ]; then
  echo 1>&2 "Can't find $DOMAIN. in 'aws route53 list-hosted-zones'"
  exit 1
fi

HOSTED_ZONE_ID_FOR_ALL_CLOUDFRONT=Z2FDTNDATAQYW2
DOMAIN_NAME=`aws cloudfront list-distributions | python -c "import json,sys; distributions = json.load(sys.stdin); print '\n'.join([distribution['DomainName'] for distribution in distributions['DistributionList']['Items'] if distribution['Comment'] == '$DOMAIN'])"`

tee new_record_set.json <<EOF
{
  "Comment": "A new record set for the zone.",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$DOMAIN.",
        "Type": "A",
        "AliasTarget": {
          "DNSName": "$DOMAIN_NAME",
          "HostedZoneId": "$HOSTED_ZONE_ID_FOR_ALL_CLOUDFRONT",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://$PWD/new_record_set.json
rm new_record_set.json

aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID
