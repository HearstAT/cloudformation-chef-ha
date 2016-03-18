#!/bin/bash -xev

#### UserData Chef HA Helper Script
### Script Params, exported in Cloudformation
# ${BUILD_DATA} == BuildInfo
# ${WAITHANDLE} == WaitHandle
# ${REGION} == AWS::Region
# ${ACCESS_KEY} == AccessKey
# ${SECRET_KEY} == SecretKey
# ${ENI} == ENI
# ${VIP} == VIP
# ${DNS} == DNS for Node
# ${PRIMEDNS} == PrimaryInternalDNS
# ${PRIMEIP} == PrimaryIP
# ${FAILDNS} == FailoverInternalDNS
# ${FAILIP} == FailoverIP
# ${VIPDNS} == VIPInternalDNS
# ${FE01DNS} == FE01DNS
# ${FE01IP} == FE01IP
# ${FE02DNS} == FE02DNS
# ${FE02IP} == FE02IP
# ${DOMAIN} == HostedZone
# ${SUBDOMAIN} == HostedSubdomain
# ${EBSID} == BackendEBSID
# ${COOKBOOK} == HACookbookGit
# ${ANALYTICSSUB} == AnalyticsSubdomain
# ${ANALYTICSDNS} == AnalyticsDNS
# ${ANALYTICSIP} == AnalyticsIP
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

# Helper function to set wait timer
function error_exit
{
  /usr/local/bin/cfn-signal -e 1 -r ${BUILD_DATA} ${WAITHANDLE}
  exit 1
}

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
     "access_key_id": "${ACCESS_KEY}",
     "secret_access_key": "${SECRET_KEY}"
  },
  "cf_ha_chef": {
     "backup_restore": false,
     "backendprimary": {
         "fqdn":  "${PRIMEDNS}",
         "ip_address": "${PRIMEIP}"
     },
     "backendfailover": {
         "fqdn": "${FAILDNS}",
         "ip_address": "${FAILIP}"
     },
     "backend_vip": {
           "fqdn": "${VIPDNS}",
           "ip_address": "${VIP}"
     },
     "frontends": {
       "fe01": {
           "fqdn": "${FE01DNS}",
           "ip_address": "${FE01IP}"
       },
       "fe02": {
           "fqdn": "${FE02DNS}",
           "ip_address": "${FE02IP}"
       }
     },
     "analytics": {
       "url":  "chef-analytics.${DOMAIN}",
       "stage_subdomain": "${ANALYTICSSUB}.${DOMAIN}",
       "fqdn": "${ANALYTICSDNS}",
       "ip_address": "${ANALYTICSIP}"
     },
     "api_fqdn": "chef.${DOMAIN}",
     "domain":  "${DOMAIN}",
     "stage_subdomain": "${SUBDOMAIN}",
     "aws_access_key_id": "${ACCESS_KEY}",
     "aws_secret_access_key": "${SECRET_KEY}",
     "ebs_volume_id": "${EBSID}"
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

su -l -c `export BERKSHELF_PATH=/root/.chef && /opt/chef/embedded/bin/berks vendor -b /root/.chef/cf_ha_chef/Berksfile` || error_exit 'Berks Vendor failed to run'
su -l -c `chef-client -c '/root/.chef/client.rb' -z --chef-zero-port 8899 -j "/root/.chef/${ROLE}.json"` || error_exit 'Failed to run chef-client'

# All is well so signal success and let CF know wait function is complete
/usr/local/bin/cfn-signal -e 0 -r "Chef Setup Complete" \'${WAITHANDLE}\'
