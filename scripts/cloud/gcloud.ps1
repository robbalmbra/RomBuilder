# Check arguments
if ($args.count -lt 3) {
  write-host "USAGE: .\gcloud.ps1 [BUILDKITE TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]"
  Exit 1
}

$token=$args[0]
$project_name=$args[1]
$zone=$args[2]

# Check if gcloud executable exists
if ((Get-Command "gcloud" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Host "Error: gcloud is not installed. Install from https://cloud.google.com/sdk/docs"
   Exit 2
}

# Check if variables are not empty
if ($token -eq ""){
  Write-Host "Error: BUILDKITE TOKEN is invalid"
  Exit 3
}

if ($project_name -eq ""){
  Write-Host "Error: PROJECT NAME is invalid"
  Exit 4
}

# Check if token is exactly 50 characters
if ($token.length -ne 50){
  Write-Host "Error: BUILDKITE TOKEN is invalid"
  Exit 5
}

$ssh_priv_key = "$HOME\.ssh\id_rsa"
if (!(Test-Path $ssh_priv_key)){
  ssh-keygen -t rsa -f $HOME\.ssh\id_rsa -N '""'
}

# Set defaults for instance
$VM_OS_PROJECT = "ubuntu-os-cloud"
$VM_OS_FAMILY = "ubuntu-1804-lts"
$VM_SIZE = "250GB"
$VM_MACHINE = "n1-standard-8"
$VM_ID = Get-Random -Maximum 100000
$VM_NAME = "buildkite-$VM_ID"

$PROJECTS_RAW = (gcloud projects list) | Out-String
$PROJECTS = $PROJECTS_RAW.split([Environment]::NewLine) | select -skip 1

# Check if project exists
$found = 0
for ($i = 0; $i -lt $PROJECTS.length; $i++) {
  if ($PROJECTS[$i] -ne ""){
    if ($PROJECTS[$i].Split()[0] -eq $project_name){
      gcloud config set project $project_name *> $null
      $found = 1
      break
    }
  }
}

# Return errors if not found
if ($found -eq 0){
  Write-Host "Error - Failed to find project name '$project_name'."
  Exit 6
}

# Check if zone exists
$ZONES_RAW = (gcloud compute zones list) | Out-String
$ZONES = $ZONES_RAW.split([Environment]::NewLine) | select -skip 1

$found = 0
for ($i = 0; $i -lt $ZONES.length; $i++) {
  if ($ZONES[$i] -ne ""){
    if ($ZONES[$i].Split()[0] -eq $zone){
      $found = 1
      break
    }
  }
}

# Return errors if not found
if ($found -eq 0){
  Write-Host "Error - Failed to find zone '$zone'. Use 'gcloud compute zones list' to list valid configurations."
  Exit 7
}

# Check machine type if specified
if ($args.count -ge 4){
  $machine=$args[3]
  $found = 0

  $MACHINE_TYPES_RAW = (gcloud compute machine-types list)
  $MACHINE_TYPES = $MACHINE_TYPES_RAW.split([Environment]::NewLine) | select -skip 1

  for ($i = 0; $i -lt $MACHINE_TYPES.length; $i++) {
    if ($MACHINE_TYPES[$i] -ne ""){
      if ($MACHINE_TYPES[$i].Split()[0] -eq $machine){
        $found = 1
        break
      }
    }
  }

  # Return errors if not found
  if ($found -eq 0){
    Write-Host "Error - Failed to find machine type '$machine'. Use 'gcloud compute machine-types list' to list valid configurations."
    Exit 8
  }
}

# Create custom startup script
$MultilineComment = @"
echo "Running custom startup script"
export BHOST="$VM_NAME"
export BTOKEN="$token"
echo -e "#!/bin/bash\n/snap/bin/gcloud compute instances delete $VM_NAME --quiet --zone $zone" > /tmp/terminate.sh
wget "https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh" -O /tmp/setup-buildtools.sh
chmod 700 /tmp/setup-buildtools.sh
chmod 700 /tmp/terminate.sh
/bin/bash /tmp/setup-buildtools.sh
chown buildkite-agent:buildkite-agent /tmp/terminate.sh
"@

# Save to temp file
$MultilineComment | Out-File -Encoding "UTF8" run.sh

# Create service account for instance scope
gcloud iam service-accounts create buildkite-user --display-name "Service Account" *> $null
$service_account = "buildkite-user@$project_name.iam.gserviceaccount.com"

# Assign roles/owner to service account
gcloud projects add-iam-policy-binding $project_name --member serviceAccount:$service_account --role roles/owner *> $null

# Create instance
$instance = (gcloud compute instances create $VM_NAME  --service-account $service_account --scopes https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform --boot-disk-type=pd-ssd --machine-type=$machine --zone=$zone --image-family=$VM_OS_FAMILY --image-project=$VM_OS_PROJECT --boot-disk-size=$VM_SIZE --metadata-from-file startup-script=run.sh 2>&1) | Out-String

if($?) {
  Write-Host "Warning - Machine has been launched"

  # Sleep to wait for instance to start
  Start-Sleep -s 5

  for(;;)
  {
    $public_ip = (gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    if($public_ip -ne ""){
      gcloud compute scp --force-key-file-overwrite --strict-host-key-checking no --zone ${zone} ${ssh_priv_key} ${VM_NAME}:/tmp/id_rsa *> $null
      if($?){
        break
      }
    }

    Start-Sleep -s 5
  }
  
  # Copy private config to instance if its exists on host
  if ((Test-Path -LiteralPath "$HOME/rom.env")){
    gcloud compute scp --strict-host-key-checking no --zone ${zone} "$HOME/rom.env" ${VM_NAME}:/tmp/rom.env *> $null
  }

  Write-Host "Complete"
}else{
  Write-Host $instance
}

# Remove temp files
Remove-Item run.sh
