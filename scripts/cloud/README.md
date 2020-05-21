## Scripts

[gcloud.sh](gcloud.sh) - Deploy buildkite build script and tools to gcloud. Configuration is adjustable

[ec2.sh](ec2.sh) - Deploy buildkite build script and tools to ec2. Configuration is adjustable. 

## Usage

**ec2.sh**

USAGE: ./ec2.sh [BUILDKITE TOKEN] [[BUNDLE]]

Example: ./ec2.sh "token" t2.2xlarge

&nbsp;

**gcloud.sh**

USAGE: ./gcloud.sh [BUILDKITE TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]

Example: ./gcloud.sh "token" eastern-crawler-277014 europe-west2-a n1-standard-2

## Notes

Double braces indicate an optional parameter
