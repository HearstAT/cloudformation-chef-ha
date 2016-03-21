# ha-chef-stack
Cloudformation Templates to setup our HA Chef Stack

This requires the use of [cf_ha_chef](https://github.com/HearstAT/cf_ha_chef) cookbook to function.

This is a nested template setup that installs Frontends, Backends, and a stand alone Analytics server.

## Info
- Built to utilize Ubuntu
- Uses Chef APT Repo for packages
- Sets up two backends to utilize keepalived and HA config

## What's Setup
* A Primary and Failover Backend, with EBS on Primary
* 2 Front Ends with a Stage file to allow setting up a seconday Domain for Blue/Green Deployments
* 1 Stand alone Analytics server
* All the items required by from the Backend Primary server will be generated first during that config, then distributed via S3 bucket.

## Requirements
- Existing VPC
- Route53 Hosted Domain/Zone
- Existing SSL Certificate (Loaded into AWS)
- IP Scheme (To create static VIP)
- SSH Security Group
- At least two subnets in different availability zones
- Citadel Chef Bucket w/ the following
  - `newrelic` folder with (optional, will just fail to start)
  - `sumologic` folder with (optional, will just fail to start)
  - `certs` folder with (Required for Blue/Green deployment)
  - `mail` folder with (optional, mail will not work)

## Parameters
- HostedZone
- ChefSubdomain
- AnalyticsSubdomain
- SSLCertificateARN
- BackendVIP
- CitadelBucket
- RestoreFile (optional)
- SignupDisable (True/False)
- SupportEmail (Optional)
- MailHost (Optional)
- MailPort (Optional)
- LicenseCount (Optional, default 25)
- EBSMountPath (Optional, `/dev/xvdf` is default)
- HACookbookGit
- BackendTemplateURL
- FrontendTemplateURL
- AnalyticsTemplateURL
- KeyName
- SSHSecurityGroup
- UserDataScript (URL for the `userdata.sh` script in this repo)
- BackupScript (True/False Option, enables a backup script that will run `knife ec` daily and copy to a S3 bucket, keeps only 10 days worth)
- VPC
- AvailabilityZoneA
- AvailabilityZoneB
- AnalyticsInstanceType
- BackendInstanceType
- FrontendInstanceType
