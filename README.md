# ha-chef-stack

Cloudformation Templates to setup our HA Chef Stack

This requires the use of [cf_ha_chef](https://github.com/HearstAT/cf_ha_chef) cookbook to function.

This is a nested template setup that installs Frontends, Backends, and a stand alone Analytics server.

## Info
* Builds out AWS HA Setup; [documentation](https://docs.chef.io/install_server_ha_aws.html)
* Built to utilize Ubuntu Trusty
* Uses Chef APT Repo for packages (Updated to the new repo)
* Sets up two backends to utilize keepalived and HA config

## What's Setup
Please see the wiki [here](https://github.com/HearstAT/cloudformation-chef-ha/wiki/Build-Steps-Process) for more specific info
* A Primary and Failover Backend, with EBS on Primary
* 2 Front Ends with a Stage file to allow setting up a secondary Subdomain/Domain for Blue/Green Deployments
* 1 Stand alone Analytics server
* All the items required by from the Backend Primary server will be generated first during that config, then distributed via S3 bucket.

## Requirements
Please see the wiki [here](https://github.com/HearstAT/cloudformation-chef-ha/wiki/Prerequisites) for more specific info
* Existing VPC
  * IP Scheme (To create static VIP)
  * SSH Security Group (Will lookup existing groups in AWS, make sure one exists)
* Route53 Hosted Domain/Zone
* Existing SSL Certificate (Loaded into AWS and provide in the params below)

## Parameters
Please see the wiki [here](https://github.com/HearstAT/cloudformation-chef-ha/wiki/Parameters) for more specific info
* Instance & Network Configuration
    * BackendInstanceType
    * FrontendInstanceType
    * AnalyticsInstanceType
    * KeyName
    * SSLCertificateARN (See [here](http://docs.aws.amazon.com/cli/latest/reference/iam/index.html#cli-aws-iam) on how to get the Cert ARN)
      * `aws iam get-server-certificate --server-certificate-name`
    * VPC
    * SSHSecurityGroup
    * AvailabilityZoneA
    * AvailabilityZoneB
    * HostedZone
    * BackendVIP
* Stack Configuration
    * BackendTemplateURL (URL for the chef_backends_nested.json in this repo)
    * FrontendTemplateURL (URL for the chef_frontends_nested.json in this repo)
    * AnalyticsTemplateURL (URL for the chef_analytics_nested.json in this repo)
* Chef Configuration
    * ChefSubdomain
    * AnalyticsSubdomain
    * SSLCRT (URL to public crt to download from)
    * SSLKEY
        * Just the bit between the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`
        * Will fix this is next version, most likely incorporate letsencrypt.
    * SignupDisable (True/False)
    * SupportEmail (Optional)
    * LicenseCount (Optional, default 25)
    * ChefDir (location for cookbook items)
    * S3DIR (Location to mount created S3 bucket for citadel items and chef backups, i.e.; /opt/chef-s3)
    * EBSMountPath (Optional, `/dev/xvdf` is default)
    * BackupEnable (True/False Option, enables a backup script that will run `knife ec` daily and copy to a S3 bucket, keeps only 10 days worth)
    * RestoreFile (optional)
* Mail Configuration (Optional)
    * MailCreds (Setup to noecho throught template)
    * MailHost (Optional)
    * MailPort (Optional)
* New Relic Configuration (Optional)
    * NewRelicAppName (Name that shows up in New Relic APM)
    * NewRelicLicense (Setup to noecho throught template)
* Sumologic Configuration (Optional)
    * SumologicAccessID (Setup to noecho throught template)
    * SumologicAccessKey (Setup to noecho throught template)
    * SumologicPassword (Setup to noecho throught template)
* External Build Items
    * Cookbook (name of cookbook)
    * CookbookGit (URL for [cf_ha_chef](https://github.com/HearstAT/cf_ha_chef))
    * CookbookGitBranch (if using something different from master)
    * UserDataScript (URL for the `userdata.sh` script in this repo)
