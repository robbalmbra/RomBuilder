# Check arguments
if ($args.count -lt 3) {
  write-host "USAGE: .\gcloud.ps1 [BUILDKITE TOKEN] [SSH PUBLIC KEY] [SSH PRIVATE KEY] [[BUNDLE]]"
  Exit 1
}

$token=$args[0]
$ssh_key=$args[1]
$ssh_privkey=$args[2]

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

if ($ssh_privkey -eq ""){
  Write-Host "Error: SSH PRIVATE KEY is invalid"
  Exit 7
}

if (!(Test-Path $ssh_privkey)){
  Write-Host "Error: SSH PRIVATE KEY doesn't exist"
  Exit 8
}

# Set defaults for instance
$bundle = "t2.2xlarge"

# Get region from settings
$REGION_RAW = (aws configure get region) | Out-String
$REGION = $REGION_RAW.Split([Environment]::NewLine) | Select -First 1

if ($REGION -eq ""){
  Write-Host "Error: aws is not configured. Please set region using aws configure"
  Exit 9
}

$REGION_TEST = (aws ec2 describe-instances 2>&1) | Out-String

if ($REGION_TEST -like '*Could not connect*'){
  Write-Host "Error: aws is not configured. Please set region using aws configure"
  Exit 10
}

# Check bundle if parameter is set
if ($args.count -ge 4){
  $bundle=$args[3]

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
    Exit 11
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
echo -e "#!/bin/bash\nsudo systemctl poweroff" > /tmp/terminate.sh
wget https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh -O /tmp/setup-buildtools.sh
chmod 700 /tmp/setup-buildtools.sh
export BHOST="$VM_NAME"
export BTOKEN="$token"
/tmp/setup-buildtools.sh
chmod 700 /tmp/terminate.sh
echo "buildkite-agent ALL=NOPASSWD: /bin/systemctl" >> /etc/sudoers
chown buildkite-agent:buildkite-agent /tmp/terminate.sh
"@

$MultilineComment2 | Out-File -Encoding ASCII run.sh

# Create instance
$instance = (aws ec2 run-instances --count 1 --instance-initiated-shutdown-behavior terminate --security-groups "buildkite" --key-name "buildkite-key" --image-id "ami-0701e7be9b2a77600" --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=300,VolumeType=gp2}' --instance-type "$bundle" --user-data file://run.sh 2>&1) | Out-String

if($?) {

  $vPSObject = $instance | ConvertFrom-Json
  $instance_id = $vPSObject.Instances['0'].InstanceId

  Write-Host "Warning - Machine has been launched"

  # Sleep to wait for instance to start
  Start-Sleep -s 5

  for(;;)
  {
    $public_ip = (aws ec2 describe-instances --instance-id $instance_id --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
    if($public_ip -ne ""){
      scp -o StrictHostKeyChecking=no -i $ssh_privkey $ssh_privkey ubuntu@${public_ip}:/tmp/id_rsa *> $null
      if($?){
        break
      }
    }

    Start-Sleep -s 5
  }

  # Copy private config to instance if its exists on host
  if ((Test-Path -LiteralPath "$HOME/rom.env")){
    scp -o StrictHostKeyChecking=no -i $ssh_privkey "$HOME/rom.env" ubuntu@$public_ip:/home/ubuntu/ > /dev/null 2>&1
  }

  Write-Host "Complete"
}else{
  Write-Host $instance
}

# Remove temp files
Remove-Item run.sh
