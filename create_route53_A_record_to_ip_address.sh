#!/bin/bash -e
if [ "$1" == "" ]; then
  echo 1>&2 "First argument should be domain name (e.g. basicruby.com)"
  exit 1
fi
DOMAIN=$1
if [ "$2" == "" ]; then
  echo 1>&2 "Second argument should be name of digitalocean droplet (e.g. basicruby)"
  exit 1
fi
DROPLET_NAME=$2

CREATE_ZONE_OUTPUT=`aws route53 create-hosted-zone --name $DOMAIN --caller-reference $DOMAIN 2>&1 || true`
if [[ "$CREATE_ZONE_OUTPUT" != *HostedZoneAlreadyExists* ]]; then
  echo "$CREATE_ZONE_OUTPUT" 1>&2
  exit 1
fi

INSTANCE_IP=`tugboat droplets | grep "$DROPLET_NAME " | egrep -oh "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" || true`
echo INSTANCE_IP=$INSTANCE_IP

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

tee new_record_set.json <<EOF
{
  "Comment": "A new record set for the zone.",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "digitalocean.$DOMAIN.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$INSTANCE_IP"
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
