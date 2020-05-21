## Scripts

[gcloud.sh](gcloud.sh) - Deploy buildkite build script and tools to gcloud. Configuration is adjustable

[ec2.sh](ec2.sh) - Deploy buildkite build script and tools to ec2. Configuration is adjustable. 

## Usage

USAGE: ./ec2.sh [BUILDKITE TOKEN]

USAGE: ./gcloud.sh [TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]

Example: ./gcloud.sh "token" eastern-crawler-277014 europe-west2-a

## Notes

Double braces indicate an optional parameter
