#!/bin/bash -xev

#### UserData Chef HA Helper Script
### Script Params, exported in Cloudformation
# ${REGION} == AWS::Region
# ${ACCESS_KEY} == AccessKey && ['aws_access_key_id']
# ${SECRET_KEY} == SecretKey && ['aws_secret_access_key']
# ${ENI} == ENI
# ${VIP} == VIP
# ${DNS} == DNS for Node
# ${PRIMARY_DNS} == PrimaryInternalDNS
# ${PRIMARY_IP} == PrimaryIP
# ${FAIL_DNS} == FailoverInternalDNS
# ${FAIL_IP} == FailoverIP
# ${VIP_DNS} == VIPInternalDNS
# ${FE01_DNS} == FE01DNS
# ${FE01_IP} == FE01IP
# ${FE02_DNS} == FE02DNS
# ${FE02_IP} == FE02IP
# ${DOMAIN} == HostedZone && ['domain']
# ${SUBDOMAIN} == HostedSubdomain
# ${EBS_ID} == BackendEBSID && ['ebs_volume_id']
# ${EBS_MOUNT_PATH} == EBSMountPath &&  ['ebs_device']
# ${BACKUP_BUCKET} ==  && ['s3']['backup_bucket']
# ${BACKUP_ENABLE} == BackupEnable && ['backup']['enable_backups']
# ${RESTORE_FILE} == RestoreFile && ['backup']['restore_file']
# ${CITADEL_BUCKET} == CitadelBucket && ['citadel']['bucket']
# ${COOKBOOK} == HACookbookGit
# ${SIGNUP_DISABLE} == SignupDisable && ['manage']['signupdisable']
# ${SUPPORT_EMAIL} == SupportEmail && ['manage']['supportemail']
# ${MAIL_HOST} == MailHost && ['mail']['relayhost']
# ${MAIL_PORT} == MailPort && ['mail']['relayport']
# ${LICENSE_COUNT} == LicenseCount && ['licensecount']
# ${ANALYTICS_SUBDOMAIN} == AnalyticsSubdomain && ['analytics']['stage_subdomain']
# ${ANALYTICS_DNS} == AnalyticsDNS && ['analytics']['fqdn']
# ${ANALYTICS_IP} == AnalyticsIP && ['analytics']['ip_address']
# ${ROLE} == Role (primary|failover|frontend|analytics)
###

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Add chef repo
curl -s https://packagecloud.io/install/repositories/chef/stable/script.deb.sh | bash

# Install cfn bootstraping tools
easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

# Install awscli
pip install awscli

# Echo out aws config
mkdir -p /root/.chef/berks-cookbooks /root/.aws/
touch /root/.aws/config /root/.aws/credentials /root/.ssh/config /root/.chef/client.rb
echo '[default]' >> /root/.aws/config
echo 'output = json' >> /root/.aws/config
echo "region = ${REGION}" >> /root/.aws/config

# Echo out AWS Credentials
echo '[default]' >> /root/.aws/credentials
echo "aws_access_key_id=${ACCESS_KEY}" >> /root/.aws/credentials
echo "aws_secret_access_key=${SECRET_KEY}" >> /root/.aws/credentials

# Set hostname
hostname  ${DNS}  || error_exit 'Failed to set hostname'
echo  ${DNS}  > /etc/hostname || error_exit 'Failed to set hostname file'

# Primary Only: Set Chef VIP
if [ ${ROLE} == 'primary' ]; then
  aws ec2 assign-private-ip-addresses --network-interface-id  ${ENI}  --allow-reassignment --private-ip-addresses  ${VIP}  || error_exit 'Failed to set VIP'
fi

# install Chef and Chef Core
apt-get install -y chef || error_exit 'Failed to install chef core'

# Install ChefHA if BackEnd
if [ ${ROLE} == 'primary' ] || [ ${ROLE} == 'failover' ]; then
  apt-get install -y chef-ha chef-server-core
elif [ ${ROLE} == 'frontend' ]; then
  apt-get install -y chef-manage chef-server-core
elif [ ${ROLE}] == 'analytics' ]; then
  apt-get install -y opscode-analytics
else
  error_exit 'Role not found'
fi

# Build out role to run

cat > "/root/.chef/${ROLE}.json" << EOF
{
  "citadel": {
     "bucket": "${CITADEL_BUCKET}",
     "access_key_id": "${ACCESS_KEY}",
     "secret_access_key": "${SECRET_KEY}"
  },
  "cf_ha_chef": {
    "backup": {
      "restore": false,
      "enable_backups": "${BACKUP_ENABLE}",
      "restore_file": "${RESTORE_FILE}"
    },
    "licensecount": "${LICENSE_COUNT}",
    "manage": {
     "signupdisable": ${SIGNUP_DISABLE},
     "supportemail": "${SUPPORT_EMAIL}"
    },
    "mail": {
     "relayhost": "${MAIL_HOST}",
     "relayport": "${MAIL_PORT}"
    },
    "s3": {
     "backup_bucket": "${BACKUP_BUCKET}"
    },
    "backendprimary": {
       "fqdn":  "${PRIMARY_DNS}",
       "ip_address": "${PRIMARY_IP}"
    },
    "backendfailover": {
       "fqdn": "${FAIL_DNS}",
       "ip_address": "${FAIL_IP}"
    },
    "backend_vip": {
         "fqdn": "${VIP_DNS}",
         "ip_address": "${VIP}"
    },
    "frontends": {
     "fe01": {
         "fqdn": "${FE01_DNS}",
         "ip_address": "${FE01_IP}"
     },
     "fe02": {
         "fqdn": "${FE02_DNS}",
         "ip_address": "${FE02_IP}"
     }
    },
    "analytics": {
     "url":  "chef-analytics.${DOMAIN}",
     "stage_subdomain": "${ANALYTICS_SUBDOMAIN}.${DOMAIN}",
     "fqdn": "${ANALYTICS_DNS}",
     "ip_address": "${ANALYTICS_IP}"
    },
    "api_fqdn": "chef.${DOMAIN}",
    "domain": "${DOMAIN}",
    "stage_subdomain": "${SUBDOMAIN}",
    "aws_access_key_id": "${ACCESS_KEY}",
    "aws_secret_access_key": "${SECRET_KEY}",
    "ebs_volume_id": "${EBS_ID}",
    "ebs_device": "${EBS_DEVICE}"
  }
  "run_list": [
    "recipe[cf_ha_chef::${ROLE}]"
  ]
}
EOF

# Install berks
/opt/chef/embedded/bin/gem install berkshelf

# Primary Only: Copy post install json and swap attribute to true if needed
if [ ${ROLE} == 'primary' ]; then
  cp /root/.chef/${ROLE}.json /root/.chef/${ROLE}_post_restore.json && sed -i 's/false/true/g' /root/.chef/${ROLE}_post_restore.json
fi

# Switch to main directory
cd /root/.chef
cat > /root/.chef/client.rb <<EOF
cookbook_path '/root/.chef/berks-cookbooks'
EOF

# Clone the CF companion cookbook
git clone ${COOKBOOK}

export BERKSHELF_PATH=/root/.chef
/opt/chef/embedded/bin/berks vendor -b /root/.chef/cf_ha_chef/Berksfile || error_exit 'Berks Vendor failed to run'
sudo su -l -c "chef-client -c '/root/.chef/client.rb' -z --chef-zero-port 8899 -j "/root/.chef/${ROLE}.json"" || error_exit 'Failed to run chef-client'
