#!/bin/bash -e
if [ "$3" == "" ]; then
  echo 1>&2 "Arg 1: base domain name (e.g. basicruby.com)"
  echo 1>&2 "Arg 2: subdomain (e.g. digitalocean.basicruby.com)"
  echo 1>&2 "Arg 3: IP address for A record to point to"
  exit 1
fi
BASE_DOMAIN=$1
SUBDOMAIN=$2
IP_ADDRESS=$3

CREATE_ZONE_OUTPUT=`aws route53 create-hosted-zone --name $BASE_DOMAIN --caller-reference $BASE_DOMAIN 2>&1 || true`
if [[ "$CREATE_ZONE_OUTPUT" != *HostedZoneAlreadyExists* ]]; then
  echo "$CREATE_ZONE_OUTPUT" 1>&2
  exit 1
fi

ZONE_ID=`aws route53 list-hosted-zones | python -c "
import json, sys
j=json.load(sys.stdin)
for zone in j['HostedZones']:
  if zone['Name'] == '$BASE_DOMAIN.':
    print zone['Id']
"`
if [ "$ZONE_ID" == "" ]; then
  echo 1>&2 "Can't find $BASE_DOMAIN. in 'aws route53 list-hosted-zones'"
  exit 1
fi

tee new_record_set.json <<EOF
{
  "Comment": "A new record set for the zone.",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$SUBDOMAIN.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$IP_ADDRESS"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://$PWD/new_record_set.json
rm new_record_set.json

aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID
