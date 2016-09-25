#!/bin/bash -ex

if [ ! -e ssl_autorenewer.user.json ]; then
  echo "Creating user..."
  aws iam create-user --user-name ssl_autorenewer > ssl_autorenewer.user.json
  chmod 0400 ssl_autorenewer.user.json
fi

if [ ! -e ssl_autorenewer.accesskey.json ]; then
  echo "Creating access key..."
  aws iam create-access-key --user-name ssl_autorenewer > ssl_autorenewer.accesskey.json
  chmod 0400 ssl_autorenewer.accesskey.json
fi

tee policy.json <<EOF
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:*", 
        "route53domains:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
aws iam put-user-policy --user-name ssl_autorenewer \
 --policy-name all-route53-permissions \
 --policy-document file://policy.json
rm policy.json

# How to delete the user:
#   aws iam list-user-policies --user-name ssl_autorenewer
#   aws iam delete-user-policy --user-name ssl_autorenewer --policy-name can-read-cloudfront-logs
#   aws iam delete-user --user-name ssl_autorenewer

tugboat ssh -n monitoring <<EOF
set -ex
sudo apt-get install -y ruby ruby-bundler

id -u ssl_autorenewer &>/dev/null || sudo useradd ssl_autorenewer
sudo mkdir -p /home/ssl_autorenewer
sudo chown ssl_autorenewer:ssl_autorenewer /home/ssl_autorenewer

sudo tee /etc/cron.d/ssl_autorenewer <<EOF2
MAILTO=dtstutz@gmail.com
5 8 * * Sat ssl_autorenewer /home/ssl_autorenewer/domains_and_tls/renew_certificate.sh vocabincontext.com && /home/ssl_autorenewer/domains_and_tls/renew_certificate.sh basicruby.com && /home/ssl_autorenewer/domains_and_tls/renew_certificate.sh danstutzman.com
EOF2

mkdir -p /home/ssl_autorenewer/domains_and_tls
chown ssl_autorenewer:ssl_autorenewer /home/ssl_autorenewer/domains_and_tls
EOF

INSTANCE_IP=`tugboat droplets | grep 'monitoring ' | egrep -oh "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+"`
echo INSTANCE_IP=$INSTANCE_IP
rsync -e "ssh -l web -p 2222" -rv -l --exclude vendor --exclude ".*" . root@$INSTANCE_IP:/home/ssl_autorenewer/domains_and_tls

# change * * to 26 21

tugboat ssh -n monitoring <<EOF
chown -R ssl_autorenewer:ssl_autorenewer /home/ssl_autorenewer/domains_and_tls
EOF
