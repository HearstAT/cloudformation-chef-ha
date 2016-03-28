# ha-chef-stack
##Note **This is a work in progress**

Cloudformation Templates to setup our HA Chef Stack

This requires the use of [cf_ha_chef](https://github.com/HearstAT/cf_ha_chef) cookbook to function.

This is a nested template setup that installs Frontends, Backends, and a stand alone Analytics server.

## Info
- Built to utilize Ubuntu Trusty
- Uses Chef APT Repo for packages
- Sets up two backends to utilize keepalived and HA config

## What's Setup
* A Primary and Failover Backend, with EBS on Primary
* 2 Front Ends with a Stage file to allow setting up a secondary Subdomain/Domain for Blue/Green Deployments
* 1 Stand alone Analytics server
* All the items required by from the Backend Primary server will be generated first during that config, then distributed via S3 bucket.

## Requirements
- Existing VPC
- Route53 Hosted Domain/Zone
- Existing SSL Certificate (Loaded into AWS) (will be copied to citadel location as chefserver.crt/.key)
- IP Scheme (To create static VIP)
- SSH Security Group (Will lookup existing groups in AWS, make sure one exists)
- At least two subnets in different availability zones
- Citadel Chef Bucket w/ the following necessary items (See [Citadel Section](#citadelsecrets-config) for more Info)

## Parameters
- HostedZone
- ChefSubdomain
- AnalyticsSubdomain
- SSLCertificateARN (See [here](http://docs.aws.amazon.com/cli/latest/reference/iam/index.html#cli-aws-iam) on how to get the Cert ARN)
  - `aws iam get-server-certificate --server-certificate-name`
- BackendVIP
- CitadelBucket (See [Citadel Section](#citadelsecrets-config))
- RestoreFile (optional)
- SignupDisable (True/False)
- SupportEmail (Optional)
- MailHost (Optional)
- MailPort (Optional)
- LicenseCount (Optional, default 25)
- EBSMountPath (Optional, `/dev/xvdf` is default)
- HACookbookGit (URL for [cf_ha_chef](https://github.com/HearstAT/cf_ha_chef))
- BackendTemplateURL (URL for the chef_backends_nested.json in this repo)
- FrontendTemplateURL (URL for the chef_frontends_nested.json in this repo)
- AnalyticsTemplateURL (URL for the chef_analytics_nested.json in this repo)
- KeyName
- SSHSecurityGroup
- UserDataScript (URL for the `userdata.sh` script in this repo)
- BackupEnable (True/False Option, enables a backup script that will run `knife ec` daily and copy to a S3 bucket, keeps only 10 days worth)
- VPC
- AvailabilityZoneA
- AvailabilityZoneB
- AnalyticsInstanceType
- BackendInstanceType
- FrontendInstanceType

## Citadel/Secrets Config
You'll need to configure some S3 items before hand.

1. A Bucket to be passed into the Params listed above.
2. Create the following folders
  - `newrelic` folder with (optional, will just fail to start)
  - `sumologic` folder with (optional, will just fail to start)
  - `certs` folder with (Required for Blue/Green deployment)
  - `mail` folder with (optional, mail will not work)

### New Relic
If using New Relic you'll need the following file(s) (case-sensitive)
* license_key
  * Content:
  ```
  $licensekey
  ```

### Sumologic
If using Sumologic you'll need the following file(s) (case-sensitive)
* accessID
  * Content:
  ```
  $accessID
  ```
* accessKey
  * Content:
  ```
  $accessKey
  ```
* password
  * Content:
  ```
  $password
  ```
### Certs
If using Sumologic you'll need the following file(s) (case-sensitive)
* chefserver.crt
  * Content:
  ```
  $cert # Can also be a cert bundle with the CA included
  ```
* chefserver.key
  * Content:
  ```
  $privatekey
  ```
### Mail
If using Sumologic you'll need the following file(s) (case-sensitive)
* sasl_passwd
  * Content:
  ```
  mail.server.com $username:$password
  ```
