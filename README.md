# ha-chef-stack
Cloudformation Templates to setup our HA Chef Stack

This requires the use of [cf_ha_chef]() cookbook to function.

This is a nested template setup that installs Frontends, Backends, and a stand alone Analytics server.

## Info
- Built to utilize Ubuntu
- Uses Chef APT Repo for packages
- Sets up two backends to utilize keepalived and HA config

## Requirements
- Existing VPC
- Route53 Hosted Domain/Zone
- Existing SSL Certificate (Loaded into AWS)
- IP Scheme (To create static VIP)
- SSH Security Group
- At least two subnets in different availability zones

## Parameters
- HostedZone
- ChefSubdomain
- AnalyticsSubdomain
- SSLCertificateARN
- BackendVIP
- HACookbookGit
- KeyName
- SSHSecurityGroup
- VPC
- AvailabilityZoneA
- AvailabilityZoneB
- AnalyticsInstanceType
- BackendInstanceType
- FrontendInstanceType
