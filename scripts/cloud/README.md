## Scripts

gcloud - Deploy buildkite build script and tools to gcloud. Configuration is adjustable

ec2 - Deploy buildkite build script and tools to ec2. Configuration is adjustable. 

## Amazon EC2

**ec2.sh**

USAGE: ./ec2.sh [BUILDKITE TOKEN] [[BUNDLE]]

Example: ./ec2.sh "token" t2.2xlarge

**ec2.ps1**

USAGE: .\ec2.ps1 [BUILDKITE TOKEN] [SSH KEY] [[BUNDLE]]

Example: .\ec2.ps1 "token" "pubkey" "t2.2xlarge"

## Google Cloud

**gcloud.sh**

USAGE: ./gcloud.sh [BUILDKITE TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]

Example: ./gcloud.sh "token" eastern-crawler-277014 europe-west2-a n1-standard-2

**gcloud.ps1**

USAGE: .\gcloud.ps1 [BUILDKITE TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]

Example: .\gcloud.ps1 "token" eastern-crawler-277014 europe-west2-a n1-standard-2


## Notes

Double braces indicate an optional parameter
Local private key is copied to instance to allow cloning of private repos
