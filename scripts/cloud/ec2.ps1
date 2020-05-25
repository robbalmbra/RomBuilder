# Check arguments
if ($args.count -lt 2) {
  write-host "USAGE: .\ec2.ps1 [BUILDKITE TOKEN] [SSH KEY] [[BUNDLE]]"
  Exit 1
}

$token=$args[0]
$ssh_key=$args[1]

# Check if aws executable exists
if ((Get-Command "aws" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Host "Error: aws is not installed."
   Exit 2
}

# Check if variables are not empty
if ($token -eq ""){
  Write-Host "Error: BUILDKITE TOKEN is invalid"
  Exit 3
}

if ($ssh_key -eq ""){
  Write-Host "Error: SSH KEY is invalid"
  Exit 4
}

if (!(Test-Path $ssh_key)){
  Write-Host "Error: SSH KEY doesn't exist"
  Exit 5
}

# Check if token is exactly 50 characters
if ($token.length -ne 50){
  Write-Host "Error: BUILDKITE TOKEN is invalid"
  Exit 6
}

# Set defaults for instance
$bundle = "t2.2xlarge"

# Get region from settings
$REGION_RAW = (aws configure get region) | Out-String
$REGION = $REGION_RAW.Split([Environment]::NewLine) | Select -First 1

if ($REGION -eq ""){
  Write-Host "Error: aws is not configured. Please set region using aws configure"
  Exit 7
}

$REGION_TEST = (aws ec2 describe-instances 2>&1) | Out-String

if ($REGION_TEST -like '*Could not connect*'){
  Write-Host "Error: aws is not configured. Please set region using aws configure"
  Exit 8
}

# Check bundle if parameter is set
if ($args.count -ge 3){
  $bundle=$args[2]

  $INSTANCE_TYPES_RAW = (aws ec2 describe-instance-types) | Out-String
  $vPSObject = $INSTANCE_TYPES_RAW | ConvertFrom-Json
  $INSTANCES = $vPSObject.InstanceTypes | where { $_.ProcessorInfo.SupportedArchitectures -eq "x86_64" }

  # Iterate over instance options
  $found = 0
  $bundles_string = "Available bundles: "
  for($i=0; $i -lt $INSTANCES.length; $i++){
    $INSTANCE_TYPE = $INSTANCES[$i].InstanceType

    if ($i -ne 0){
      $bundles_string+=", "
    }

    $bundles_string+=$INSTANCE_TYPE

    if ($bundle -eq $INSTANCE_TYPE){
      $found = 1
    }
  }

  # Error and return valid bundles if failed
  if ($found -eq 0){
    Write-Host "Error: BUNDLE '$bundle' is invalid"
    Write-Host $bundles_string
    Exit 9
  }

}

# Create security group to allow ssh from port 22
aws ec2 create-security-group --group-name buildkite --description "Buildkite group" *> $null
aws ec2 authorize-security-group-ingress --group-name buildkite --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION *> $null

# Import public key to ec2
aws ec2 delete-key-pair --key-name "buildkite-key" *> $null
aws ec2 import-key-pair --key-name "buildkite-key" --public-key-material fileb://$ssh_key *> $null

# Create random instance name
$VM_ID = Get-Random -Maximum 100000
$VM_NAME = "buildkite-$VM_ID"

# Create startup file for instance
$MultilineComment2 = @"
#!/bin/bash
echo "Running custom startup script"
hostname "$VM_NAME"
apt install -y git curl wget
echo -e "#!/bin/bash\nsudo systemctl halt -i" > /tmp/terminate.sh
wget https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh -O /tmp/setup-buildtools.sh
chmod 700 /tmp/setup-buildtools.sh
chmod 700 /tmp/terminate.sh
export BHOST="$VM_NAME"
export BTOKEN="$token"
/tmp/setup-buildtools.sh
echo "buildkite-agent ALL=NOPASSWD: /bin/systemctl" > /etc/sudoers
chown buildkite-agent:buildkite-agent /tmp/terminate.sh
"@

$MultilineComment2 | Out-File -Encoding ASCII run.sh

# Create instance
$instance = (aws ec2 run-instances --count 1 --instance-initiated-shutdown-behavior terminate --security-groups "buildkite" --key-name "buildkite-key" --image-id "ami-0701e7be9b2a77600" --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=300,VolumeType=gp2}' --instance-type "$bundle" --user-data file://run.sh 2>&1) | Out-String

if($?) {
  Write-Host "Warning - Machine has been launched"
}else{
  Write-Host $instance
}

# Remove temp files
Remove-Item run.sh
