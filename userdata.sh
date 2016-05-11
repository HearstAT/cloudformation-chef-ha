#!/bin/bash -xev

#### UserData Chef HA Helper Script v 1.2
### Script Params, exported in Cloudformation
# ${REGION} == AWS::Region
# ${ACCESS_KEY} == AccessKey && ['aws_access_key_id']
# ${SECRET_KEY} == SecretKey && ['aws_secret_access_key']
# ${IAM_ROLE} == IAMRole
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
# ${SECONDARY_DOMAIN} == SecondaryDomain
# ${SUBDOMAIN} == HostedSubdomain
# ${EBS_ID} == BackendEBSID && ['ebs_volume_id']
# ${EBS_MOUNT_PATH} == EBSMountPath &&  ['ebs_device']
# ${ENVIRONMENT} == Environment
# ${BUCKET} == ChefBucket || ExternalBucket
# ${BACKUP_ENABLE} == BackupEnable && ['backup']['enable_backups']
# ${RESTORE_FILE} == RestoreFile && ['backup']['restore_file']
# ${CHEFDIR} == ChefDir
# ${S3DIR} == S3Dir
# ${DB_CHOICE} == DBChoice
# ${DB_USER} == DBUser
# ${DB_PASSWORD} == DBPassword
# ${DB_PORT} == DBPort
# ${DB_URL} == DBURL
# ${COOKBOOK_CHOICE} == CookbookChoice
# ${COOKBOOK_BUCKET} == CookbookBucket
# ${COOKBOOK} == Cookbook
# ${COOKBOOK_GIT} == CookbookGit
# ${COOKBOOK_BRANCH} == CookbookGitBranch
# ${SIGNUP_DISABLE} == SignupDisable && ['manage']['signupdisable']
# ${SUPPORT_EMAIL} == SupportEmail && ['manage']['supportemail']
# ${MAIL_HOST} == MailHost && ['mail']['relayhost']
# ${MAIL_PORT} == MailPort && ['mail']['relayport']
# ${MAIL_CREDS} == MailCreds
# ${NR_LICENSE} == NewRelicLicense
# ${NR_APPNAME} == NewRelicAppName
# ${NR_ENABLE} == NewRelicEnable
# ${SUMO_ENABLE} == SumologicEnable
# ${SUMO_ACCESS_ID} == SumologicAccessID
# ${SUMO_ACCESS_KEY} == SumologicAccessKey
# ${SUMO_PASSWORD} == SumologicPassword
# ${LICENSE_COUNT} == LicenseCount && ['licensecount']
# ${ANALYTICS_SUBDOMAIN} == AnalyticsSubdomain && ['analytics']['stage_subdomain']
# ${ANALYTICS_DNS} == AnalyticsDNS && ['analytics']['fqdn']
# ${ANALYTICS_IP} == AnalyticsIP && ['analytics']['ip_address']
# ${ROLE} == Role (primary|failover|frontend|analytics)
###

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install S3FS Dependencies
sudo apt-get install -y automake autotools-dev g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config

# Install S3FS

# If directory exists, remove it
if [ -d "/tmp/s3fs-fuse" ]; then
  rm -rf /tmp/s3fs-fuse
fi

# If s3fs command doesn't exist, install
if [ ! -f "/usr/local/bin/s3fs" ]; then
  cd /tmp
  git clone https://github.com/s3fs-fuse/s3fs-fuse.git || error_exit 'Failed to clone s3fs-fuse'
  cd s3fs-fuse
  ./autogen.sh || error_exit 'Failed to run autogen for s3fs-fuse'
  ./configure || error_exit 'Failed to run configure for s3fs-fuse'
  make || error_exit 'Failed to make s3fs-fuse'
  sudo make install || error_exit 'Failed run make-install s3fs-fuse'
fi

# Create S3FS Mount Directory
if [ ! -d "${S3DIR}" ]; then
  mkdir ${S3DIR}
fi

# Mount S3 Bucket to Directory
s3fs -o allow_other -o umask=000 -o use_cache=/tmp -o iam_role=${IAM_ROLE} -o endpoint=${REGION} ${BUCKET} ${S3DIR} || error_exit 'Failed to mount s3fs'

echo -e "${BUCKET} ${S3DIR} fuse.s3fs rw,_netdev,allow_other,umask=0022,use_cache=/tmp,iam_role=${IAM_ROLE},endpoint=${REGION},retries=5,multireq_max=5 0 0" >> /etc/fstab || error_exit 'Failed to add mount info to fstab'

# Sleep to allow s3fs to connect
sleep 20

if [ ${ROLE} == 'primary' ]; then
    # make directories
    mkdir -p ${S3DIR}/mail ${S3DIR}/newrelic ${S3DIR}/sumologic ${S3DIR}/db ${S3DIR}/aws

    ## AWS Creds
    echo "${ACCESS_KEY}" | tr -d '\\n' > ${S3DIR}/aws/access_key
    echo "${SECRET_KEY}" | tr -d '\\n' > ${S3DIR}/aws/secret_key

    ## DB Creds
    if [ ${DB_CHOICE} == 'external' ]; then
        echo "${DB_USER}" | tr -d '\\n' > ${S3DIR}/db/username
        echo "${DB_PASSWORD}" | tr -d '\\n' > ${S3DIR}/db/password
    fi

    ## Mail
    echo "${MAIL_HOST} ${MAIL_CREDS}" | tr -d '\\n' > ${S3DIR}/mail/creds

    ## New Relic
    echo "${NR_LICENSE}" | tr -d '\\n' > ${S3DIR}/newrelic/license

    ## Sumologic
    echo "${SUMO_PASSWORD}" | tr -d '\\n' > ${S3DIR}/sumologic/password
    echo "${SUMO_ACCESS_ID}" | tr -d '\\n' > ${S3DIR}/sumologic/access_id
    echo "${SUMO_ACCESS_KEY}" | tr -d '\\n' > ${S3DIR}/sumologic/access_key
fi



# install chef
curl -L https://omnitruck.chef.io/install.sh | bash || error_exit 'could no install chef'

# Install cfn bootstraping tools
easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz || error_exit "could not install cfn bootstrap tools"

if [ ${ROLE} == 'primary' ]; then
    # Install awscli
    pip install awscli || error_exit 'could not install aws cli tools'
    # Run aws config
    if [ -n $(command -v aws) ]; then
        set +xv
        echo "Setting up AWS Config, turning of verbose"
        aws configure set default.region ${REGION} || error_exit 'Failed to set aws region'
        aws configure set aws_access_key_id ${ACCESS_KEY} || error_exit 'Failed to set aws access key'
        aws configure set aws_secret_access_key ${SECRET_KEY} || error_exit 'Failed to set aws secret key'
        echo "AWS Config complete, turning verbose back on"
        set -xv
    else
        error_exit 'awscli does not exist!'
    fi
    # Primary Only: Set Chef VIP
    aws ec2 assign-private-ip-addresses --network-interface-id  ${ENI}  --allow-reassignment --private-ip-addresses  ${VIP}  || error_exit 'Failed to set VIP'

    export SIGNUP_DISABLE='true'

    if [ ${ENVIRONMENT} == 'production' ]; then
        LE_ENDPOINT='https://acme-v01.api.letsencrypt.org'
    else
        LE_ENDPOINT='https://acme-staging.api.letsencrypt.org'
    fi

    # Conditional Variable Set
    if [ ${DB_CHOICE} == 'internal' ]; then
        DB_EXT_ENABLE='false'
    else
        DB_EXT_ENABLE='true'
    fi

    if [ ${COOKBOOK_CHOICE} == 'internal' ]; then
        CB_EXT_ENABLE='false'
    else
        CB_EXT_ENABLE='true'
    fi
fi

mkdir -p /etc/chef/ohai/hints || error_exit 'Failed to create ohai folder'
touch /etc/chef/ohai/hints/ec2.json || error_exit 'Failed to create ec2 hint file'
touch /etc/chef/ohai/hints/iam.json || error_exit 'Failed to create iam hint file'

# Create Chef Directory
mkdir -p ${CHEFDIR}
mkdir -p /etc/chef

# Set hostname
hostname  ${DNS}  || error_exit 'Failed to set hostname'
echo  ${DNS}  > /etc/hostname || error_exit 'Failed to set hostname file'


cat > "${CHEFDIR}/${ROLE}.json" << EOF
{
    "citadel": {
        "bucket": "${BUCKET}"
    },
    "letsencrypt": {
        "contact": "mailto:${SUPPORT_EMAIL}",
        "endpoint": "${LE_ENDPOINT}"
    },
    "${COOKBOOK}": {
        "backup": {
            "restore": false,
            "enable_backups": ${BACKUP_ENABLE},
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
        "database": {
            "ext_enable": ${DB_EXT_ENABLE},
            "port": "${DB_PORT}",
            "url": "${DB_URL}"
        },
        "cookbook": {
            "ext_enable" ${CB_EXT_ENABLE},
            "bucket": "${COOKBOOK_BUCKET}"
        },
        "s3": {
            "dir": "${S3DIR}"
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
        "newrelic": {
            "appname": "${NR_APPNAME}",
            "enable": ${NR_ENABLE}
        },
        "sumologic": {
            "enable": ${SUMO_ENABLE}
        },
        "analytics": {
            "url":  "chef-analytics.${DOMAIN}",
            "stage_subdomain": "${ANALYTICS_SUBDOMAIN}.${DOMAIN}",
            "fqdn": "${ANALYTICS_DNS}",
            "ip_address": "${ANALYTICS_IP}"
        },
        "api_fqdn": "chef.${DOMAIN}",
        "prime_domain": "${DOMAIN}",
        "secondary_domain": "${SECONDARY_DOMAIN}",
        "stage_subdomain": "${SUBDOMAIN}",
        "ebs_volume_id": "${EBS_ID}",
        "ebs_device": "${EBS_MOUNT_PATH}"
    },
    "run_list": [
        "recipe[apt-chef]",
        "recipe[chef-client]",
        "recipe[${COOKBOOK}::${ROLE}]"
    ]
}
EOF

# Install berks
/opt/chef/embedded/bin/gem install berkshelf

# Primary Only: Copy post install json and swap attribute to true if needed
if [ ${ROLE} == 'primary' ]; then
  cp ${CHEFDIR}/${ROLE}.json ${CHEFDIR}/${ROLE}_post_restore.json && sed -i 's/\"restore\": false/\"restore\": true/g' ${CHEFDIR}/${ROLE}_post_restore.json

  cp ${CHEFDIR}/${ROLE}.json ${CHEFDIR}/certs.json && sed -i "s/::${ROLE}/::certs/g" ${CHEFDIR}/certs.json


cat > /etc/chef/client.rb <<EOF
cookbook_path "${CHEFDIR}/berks-cookbooks"
json_attribs "${CHEFDIR}/certs.json"
chef_zero.enabled
local_mode true
chef_zero.port 8899
EOF

else
cat > ${CHEFDIR}/runner.json <<EOF
{"run_list":["recipe[apt-chef]","recipe[chef-client]"]}
EOF

cat > /etc/chef/client.rb <<EOF
cookbook_path "${CHEFDIR}/berks-cookbooks"
json_attribs "${CHEFDIR}/runner.json"
chef_zero.enabled
local_mode true
chef_zero.port 8899
EOF

fi

# Switch to main directory
cd ${CHEFDIR}
cat > ${CHEFDIR}/client.rb <<EOF
cookbook_path "${CHEFDIR}/berks-cookbooks"
json_attribs "${CHEFDIR}/${ROLE}.json"
chef_zero.enabled
local_mode true
chef_zero.port 8899
EOF

cat > "${CHEFDIR}/Berksfile" <<EOF
source 'https://supermarket.chef.io'
cookbook "${COOKBOOK}", git: '${COOKBOOK_GIT}', branch: '${COOKBOOK_BRANCH}'
EOF

sudo su -l -c "cd ${CHEFDIR} && export BERKSHELF_PATH=${CHEFDIR} && /opt/chef/embedded/bin/berks vendor" || error_exit 'Berks Vendor failed to run'
sudo su -l -c "chef-client -c "${CHEFDIR}/client.rb"" || error_exit 'Failed to run chef-client'
