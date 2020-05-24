#!/bin/bash

# Check if user has requirements installed
if ! [ -x "$(command -v aws)" ]; then
  echo '$0 - Error: aws is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v aws configure get region)" ]; then
  echo '$0 - Error: aws is not configured.' >&2
  exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  echo '$0 - Error: jq is not installed.' >&2
  exit 1
fi

# Check if user has a ssh private key to import to ec2
if [ ! -f ~/.ssh/id_rsa ]; then
  cat /dev/zero | ssh-keygen -q -N ""
fi

if [ $# -lt 1 ]; then
  echo "USAGE: $0 [TOKEN] [[BUNDLE]]"
  exit 1
fi

# Input checks
if [ -z $1 ]; then
  echo "$0 - Error: TOKEN is invalid"
  exit 2
fi

TOKEN=$1
token_size=${#TOKEN}

if [ $token_size -ne 50 ]; then
  echo "Error - TOKEN is invalid"
  exit 3
fi

# Set default bundle
BUNDLE="t2.2xlarge"

# Get region from settings
REGION=$(aws configure get region)

# Check bundle
if [ -n "$2" ]; then
  bundles=($(aws ec2 describe-instance-types | jq -r '.InstanceTypes[] | select(.ProcessorInfo.SupportedArchitectures[] | contains("x86_64")) .InstanceType'))
  if [[ ! " ${bundles[@]} " =~ " $2 " ]]; then
    echo "$0 - Error: BUNDLE '$2' is invalid"
    bundles_string="Available bundles: "

    i=0
    for bundle in "${bundles[@]}"
    do
      if [ $i -ne 0 ]; then
        bundles_string+=", "
      fi

      bundles_string+=$bundle
      ((i=i+1))
    done

    echo $bundles_string
    exit 4
  fi
  BUNDLE=$2
fi

# Create security group to allow ssh from port 22
aws ec2 create-security-group --group-name buildkite --description “Buildkite group” > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-name buildkite --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION > /dev/null 2>&1

# Import private key to ec2
aws ec2 delete-key-pair --key-name "buildkite-key" > /dev/null 2>&1
aws ec2 import-key-pair --key-name "buildkite-key" --public-key-material fileb://~/.ssh/id_rsa.pub > /dev/null 2>&1

# Create root parititon with 300GB
cat > mapping.json <<EOL
[
    {
        "DeviceName": "/dev/sda1",
        "Ebs": {
            "DeleteOnTermination": true,
            "VolumeSize": 300,
            "VolumeType": "gp2"
        }
    }
]
EOL

BUILD_HOST="buildkite-$((1 + RANDOM % 10000000))"
BUILD_TOKEN="$1"

# Create startup file for instance
cat > user-data.txt <<EOF
#!/bin/bash
hostname "$BUILD_HOST"
apt install -y git curl wget
echo -e "#!/bin/bash\nsystemctl halt -i" > /tmp/terminate.sh
wget https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh -O /tmp/setup-buildtools.sh
chmod 700 /tmp/setup-buildtools.sh
chmod 700 /tmp/terminate.sh
export BHOST="$BUILD_HOST"
export BTOKEN="$BUILD_TOKEN"
/tmp/setup-buildtools.sh
chown root:buildkite-agent /bin/systemctl
chown buildkite-agent:buildkite-agent /tmp/terminate.sh
EOF

# Create Instance
instance=$(aws ec2 run-instances --count 1 \
                      --security-groups "buildkite" \
                      --key-name "buildkite-key" \
                      --instance-initiated-shutdown-behavior terminate \
                      --image-id "ami-0701e7be9b2a77600" \
                      --block-device-mappings file://mapping.json \
                      --instance-type "$BUNDLE" \
                      --user-data file://user-data.txt 2>&1)

# Something went wrong, return error
if [ $? -ne 0 ]; then
  echo $instance
else
  echo "Warning - Machine has been launched"
fi

# Remove temp files
rm -rf mapping.json > /dev/null 2>&1
rm -rf user-data.txt > /dev/null 2>&1
