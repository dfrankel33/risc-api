param(
  $ASSESSMENT_CODE,
  $API_KEY,
  $USER_ID,
  $USER_PASSWORD,
  $CUSTOMER_NAME,
  $OUTPUT_PATH
)

### FUNCTIONS ###
function Generate-Token ($HASHED_PASSWORD, $USER_ID, $ASSESSMENT_CODE) {
  try {
    
    $contentType = "application/json"
    
    $body = [ordered]@{"userid"=$USER_ID;"password"=$HASHED_PASSWORD;"assessmentcode"=$ASSESSMENT_CODE} | ConvertTo-Json

    $authResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/getAuthToken" -Method Post -ContentType $contentType -Body $body

    return $authResult
  }
  catch {
      Write-Output "Error generating token! $($_ | Out-String)" 
  }
}

function Get-StackSummary ($TOKEN, $ASSESSMENT_CODE) {
  try {
    
    $contentType = "application/json"
    $header = @{"token"=$TOKEN;"assessmentcode"=$ASSESSMENT_CODE}

    $stackSumResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/stacks/getSummary" -Method Get -ContentType $contentType -Headers $header

    return $stackSumResult
  }
  catch {
      Write-Output "Error getting stack summary! $($_ | Out-String)" 
  }
}

function Get-StackAssets ($TOKEN, $ASSESSMENT_CODE, $STACK_ID) {
  try {
    
    $contentType = "application/json"
    $header = @{"token"=$TOKEN;"assessmentcode"=$ASSESSMENT_CODE}

    $assetSumResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/assets/getAssets/byStack/$STACK_ID" -Method Get -ContentType $contentType -Headers $header

    return $assetSumResult
  }
  catch {
      Write-Output "Error getting asset summary! $($_ | Out-String)" 
  }
}

function Get-StackConnectivity ($TOKEN, $ASSESSMENT_CODE, $STACK_ID) {
  try {
    
    $contentType = "application/json"
    $header = @{"token"=$TOKEN;"assessmentcode"=$ASSESSMENT_CODE}

    $extConnectivityResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/stacks/getConnectivity/$STACK_ID" -Method Get -ContentType $contentType -Headers $header

    return $extConnectivityResult
  }
  catch {
      Write-Output "Error getting external device connectivity detail! $($_ | Out-String)" 
  }
}

function Get-Checks ($TOKEN, $ASSESSMENT_CODE) {
  try {
    
    $contentType = "application/json"
    $header = @{"token"=$TOKEN;"assessmentcode"=$ASSESSMENT_CODE}

    $checksResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/ucel/getChecks" -Method Get -ContentType $contentType -Headers $header

    return $checksResult
  }
  catch {
      Write-Output "Error getting checks! $($_ | Out-String)" 
  }
}

function Get-CheckData ($TOKEN, $ASSESSMENT_CODE, $CHECK_ID) {
  try {
    
    $contentType = "application/json"
    $header = @{"token"=$TOKEN;"assessmentcode"=$ASSESSMENT_CODE}

    $checkAssetsResult = Invoke-RestMethod -UseBasicParsing -Uri "https://api.riscnetworks.com/1_0/ucel/getAssets/$CHECK_ID" -Method Get -ContentType $contentType -Headers $header

    return $checkAssetsResult
  }
  catch {
      Write-Output "Error getting check data! $($_ | Out-String)" 
  }
}

#### AUTH ####

# Generate MD5 Hash
$stringAsStream = [System.IO.MemoryStream]::new()
$writer = [System.IO.StreamWriter]::new($stringAsStream)
$writer.write($USER_PASSWORD)
$writer.Flush()
$stringAsStream.Position = 0
$hashedPwd = ((Get-FileHash -InputStream $stringAsStream -Algorithm MD5).Hash).ToUpper()
$concatApiPwd = $API_KEY + $hashedPwd 

$stringAsStream = [System.IO.MemoryStream]::new()
$writer = [System.IO.StreamWriter]::new($stringAsStream)
$writer.write($concatApiPwd)
$writer.Flush()
$stringAsStream.Position = 0
$hashedApiPwd = ((Get-FileHash -InputStream $stringAsStream -Algorithm MD5).Hash).ToLower()

# Retrieve Token
$token = (Generate-Token -HASHED_PASSWORD $hashedApiPwd -USER_ID $USER_ID -ASSESSMENT_CODE $ASSESSMENT_CODE).token

#### SCRIPT ####
$result = @()
$masterStackArray = @()

# Get all stacks, assets, connections, and build the $masterStackArray 
$stacks = (Get-StackSummary -TOKEN $token -ASSESSMENT_CODE $ASSESSMENT_CODE).assets
foreach ($stack in $stacks){
  if (($stack.stack_name -ne "Isolated Devices") -and ($stack.stack_name -ne "No Connectivity") -and ($stack.stack_name -notlike "RISC*")){
    $token = (Generate-Token -HASHED_PASSWORD $hashedApiPwd -USER_ID $USER_ID -ASSESSMENT_CODE $ASSESSMENT_CODE).token
    $stackassets = (Get-StackAssets -TOKEN $token -ASSESSMENT_CODE $ASSESSMENT_CODE -STACK_ID $stack.stackid).assets
    $stackconnections = (Get-StackConnectivity -TOKEN $token -ASSESSMENT_CODE $ASSESSMENT_CODE -STACK_ID $stack.stackid).connectivity
    $stackobject = New-Object psobject
    $stackobject | Add-Member -MemberType NoteProperty -Name "stack" -Value $stack
    $stackobject | Add-Member -MemberType NoteProperty -Name "assets" -Value $stackassets
    $stackobject | Add-Member -MemberType NoteProperty -Name "connectivity" -Value $stackconnections
    $masterStackArray += $stackobject
  }
}

# Loop through each stack
foreach ($stack in $masterStackArray) {
  $object = New-Object psobject
  $object | Add-Member -MemberType NoteProperty -Name "Application Name" -Value $stack.stack.stack_name
  $object | Add-Member -MemberType NoteProperty -Name "Application Type" -Value ($stack.stack.tags | where tagkey -eq 'Application Type').tagvalue
  $object | Add-Member -MemberType NoteProperty -Name "Business Group" -Value ($stack.stack.tags | where tagkey -eq 'Business Group').tagvalue
  $object | Add-Member -MemberType NoteProperty -Name "Business Critical" -Value ($stack.stack.tags | where tagkey -eq 'Business Critical').tagvalue
  $object | Add-Member -MemberType NoteProperty -Name "Sequence Preference" -Value ($stack.stack.tags | where tagkey -eq 'Sequence Preference').tagvalue

  if ($stack.stack.tags | where tagkey -eq 'Presentation Layer Version') {
    $object | Add-Member -MemberType NoteProperty -Name "Presentation Layer Version" -Value ($stack.stack.tags | where tagkey -eq 'Presentation Layer Version').tagvalue
  } else {
    $presLayerAssetTags = ($stack.assets.tags | where tagkey -eq 'Presentation Layer Version').tagvalue 
    if ($presLayerAssetTags.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "Presentation Layer Version" -Value $([string]::Join(", ",($stack.assets.tags | where tagkey -eq 'Presentation Layer Version').tagvalue))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "Presentation Layer Version" -Value ($stack.assets.tags | where tagkey -eq 'Presentation Layer Version').tagvalue
    }
  }

  if ($stack.stack.tags | where tagkey -eq 'Business Layer Version') {
    $object | Add-Member -MemberType NoteProperty -Name "Business Layer Version" -Value ($stack.stack.tags | where tagkey -eq 'Business Layer Version').tagvalue
  } else {
    $busLayerAssetTags = ($stack.assets.tags | where tagkey -eq 'Business Layer Version').tagvalue 
    if ($busLayerAssetTags.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "Business Layer Version" -Value $([string]::Join(", ",($stack.assets.tags | where tagkey -eq 'Business Layer Version').tagvalue))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "Business Layer Version" -Value ($stack.assets.tags | where tagkey -eq 'Business Layer Version').tagvalue
    }
  }

  if ($stack.stack.tags | where tagkey -eq 'App Server Version') {
    $object | Add-Member -MemberType NoteProperty -Name "App Server Version" -Value ($stack.stack.tags | where tagkey -eq 'App Server Version').tagvalue
  } else {
    $appSvrAssetTags = ($stack.assets.tags | where tagkey -eq 'App Server Version').tagvalue 
    if ($appSvrAssetTags.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "App Server Version" -Value $([string]::Join(", ",$appSvrAssetTags))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "App Server Version" -Value $appSvrAssetTags
    }
  }

  $appAssets = $stack.assets | foreach { foreach ($tag in $_.tags) { if (($tag.tagkey -eq 'Tier') -and ($tag.tagvalue -like 'App*')) { $_ } } }
  if ($appAssets.count -gt 1){
    $os = ($appAssets.data | select os,os_version | foreach { if ($_.os -ne $null) {"$($_.os) ($($_.os_version))" }})
    $appSvrOS = $([string]::Join(", ",$os))
  } elseif ($appAssets.count -eq 1) {
    $appSvrOS = "$($appAssets.data.os) ($($appAssets.data.os_version))"
  } else {
    $appSvrOS = "N/A - App Tier not specified"
  }
  $object | Add-Member -MemberType NoteProperty -Name "App Server OS" -Value $appSvrOS

  if ($stack.stack.tags | where tagkey -eq 'Web Server Version') {
    $object | Add-Member -MemberType NoteProperty -Name "Web Server Version" -Value ($stack.stack.tags | where tagkey -eq 'Web Server Version').tagvalue
  } else {
    $webSvrAssetTags = ($stack.assets.tags | where tagkey -eq 'Web Server Version').tagvalue 
    if ($webSvrAssetTags.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "Web Server Version" -Value $([string]::Join(", ",($stack.assets.tags | where tagkey -eq 'Web Server Version').tagvalue))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "Web Server Version" -Value ($stack.assets.tags | where tagkey -eq 'Web Server Version').tagvalue
    }
  }

  $webAssets = $stack.assets | foreach { foreach ($tag in $_.tags) { if (($tag.tagkey -eq 'Tier') -and ($tag.tagvalue -eq 'Web')) { $_ } } }
  if ($webAssets.count -gt 1){
    $os = ($webAssets.data | select os,os_version | foreach { if ($_.os -ne $null) {"$($_.os) ($($_.os_version))" }})
    $webSvrOS = $([string]::Join(", ",$os))
  } elseif ($webAssets.count -eq 1) {
    $webSvrOS = "$($webAssets.data.os) ($($webAssets.data.os_version))"
  } else {
    $webSvrOS = "N/A - Web Tier not specified"
  }
  $object | Add-Member -MemberType NoteProperty -Name "Web Server OS" -Value $webSvrOS

  $hwEOL = @()
  $swEOL = @()
  foreach ($asset in $stack.assets){
    if ($asset.device_issues.issue_name -eq "Server End of Life") {
      $hwIssue = "$(($asset.device_issues | where {$_.issue_name -eq 'Server End of Life'}).affected_instance_name) ($($asset.data.hostname))"
      $hwEOL += $hwIssue
    }
    if ($asset.device_issues.issue_name -like "*OS End of Life") {
      $swIssue = "$(($asset.device_issues | where {$_.issue_name -like `"*OS End of Life`"}).affected_instance_name) ($($asset.data.hostname))"
      $swEOL += $swIssue
    }
  }
  $object | Add-Member -MemberType NoteProperty -Name "End of Life Hardware" -Value $([string]::Join(", ",$hwEOL))
  $object | Add-Member -MemberType NoteProperty -Name "Out of Support Software" -Value $([string]::Join(", ",$swEOL))


  $result += $object
  

  $dependantApps = @()
  $sourceApps = ($stack.connectivity | where source_location_name -ne $stack.stack.stack_name).source_location_name
  $destApps = ($stack.connectivity | where dest_location_name -ne $stack.stack.stack_name).dest_location_name
  $dependantApps += $sourceApps
  $dependantApps += $destApps
  $dependantApps = $dependantApps | select -Unique

  $object | Add-Member -MemberType NoteProperty -Name "Dependant Applications" -Value $([string]::Join(", ",$dependantApps))

  $technicallyCoupledApps = @()
  if (($dependantApps -like "*Shared DB*") -or ($dependantApps -like "*SharedDB*") -or ($dependantApps -like "*Shared_DB*")){
    $sharedDbStackNames = $dependantApps | where { ($_ -like "*Shared DB*") -or ($_ -like "*SharedDB*") -or ($_ -like "*Shared_DB*")}
    $dbVersion = @()
    $dbOS = @()
    foreach ($sharedDbStackName in $sharedDbStackNames){
      $sharedDbStack = $masterStackArray | where {$_.stack.stack_name -eq $sharedDbStackName} 
      $coupledSourceApps = ($sharedDbStack.connectivity | where (source_location_name -ne $stack.stack.stack_name) -and (source_location_name -ne $sharedDbStackName)).source_location_name
      $coupledDestApps = ($sharedDbStack.connectivity | where (dest_location_name -ne $stack.stack.stack_name) -and (dest_location_name -ne $sharedDbStackName)).dest_location_name
      $technicallyCoupledApps += $coupledSourceApps
      $technicallyCoupledApps += $coupledDestApps

      $dbAssets = $sharedDbStack.assets
      if ($dbAssets.count -gt 1){
        $os = ($dbAssets.data | select os,os_version | foreach { if ($_.os -ne $null) {"$($_.os) ($($_.os_version))" }})
        $dbSvrOS = $([string]::Join(", ",$os))
      } else {
        $dbSvrOS = "$($dbAssets.data.os) ($($webAssets.data.os_version))"
      } 
      $dbOS += $dbSvrOS

      if ($sharedDbStack.stack.tags | where tagkey -eq 'Database Version') {
        $dbVer = ($sharedDbStack.stack.tags | where tagkey -eq 'Database Version').tagvalue
      } else {
        $dbVer = ($sharedDbStack.assets.tags | where tagkey -eq 'Database Version').tagvalue 
      }
      $dbVersion += $dbVer
    }

    if ($dbVersion.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "Database Version" -Value $([string]::Join(", ",$dbVersion))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "Database Version" -Value $dbVersion
    }
    if ($dbOS.count -gt 1){
      $object | Add-Member -MemberType NoteProperty -Name "Database OS" -Value $([string]::Join(", ",$dbOS))
    } else {
      $object | Add-Member -MemberType NoteProperty -Name "Database OS" -Value $dbOS
    }

  } else {

    if ($stack.stack.tags | where tagkey -eq 'Database Version') {
      $object | Add-Member -MemberType NoteProperty -Name "Database Version" -Value ($stack.stack.tags | where tagkey -eq 'Database Version').tagvalue
    } else {
      $dbAssetTags = ($stack.assets.tags | where tagkey -eq 'Database Version').tagvalue 
      if ($dbAssetTags.count -gt 1){
        $object | Add-Member -MemberType NoteProperty -Name "Database Version" -Value $([string]::Join(", ",($stack.assets.tags | where tagkey -eq 'Database Version').tagvalue))
      } else {
        $object | Add-Member -MemberType NoteProperty -Name "Database Version" -Value ($stack.assets.tags | where tagkey -eq 'Database Version').tagvalue
      }
    }

    $dbAssets = $stack.assets | foreach { foreach ($tag in $_.tags) { if (($tag.tagkey -eq 'Tier') -and ($tag.tagvalue -eq 'Database')) { $_ } } }
    if ($dbAssets.count -gt 1){
      $os = ($dbAssets.data | select os,os_version | foreach { if ($_.os -ne $null) {"$($_.os) ($($_.os_version))" }})
      $dbSvrOS = $([string]::Join(", ",$os))
    } elseif ($dbAssets.count -eq 1) {
      $dbSvrOS = "$($dbAssets.data.os) ($($dbAssets.data.os_version))"
    } else {
      $dbSvrOS = "N/A - DB Tier not specified"
    }
    $object | Add-Member -MemberType NoteProperty -Name "Database OS" -Value $dbSvrOS

  }

  $object | Add-Member -MemberType NoteProperty -Name "Technically Coupled Applications" -Value $([string]::Join(", ",$technicallyCoupledApps))


}

$date = Get-Date -Format yyyy-MM-dd_HH-mm
if (!$OUTPUT_PATH){
  $OUTPUT_PATH = "."+[IO.Path]::DirectorySeparatorChar
}
$result | Export-Csv "$OUTPUT_PATH$CUSTOMER_NAME`_$date.csv"
