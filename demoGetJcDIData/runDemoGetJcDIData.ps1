# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# Defining the track-back timing
$backTrackingDate = (get-date).AddDays(-1) # For the past hour

Write-Output "PowerShell Timer trigger function executed at:$currentUTCtime"
Write-Output "This function will fetch directory insight data!!!"
# Get the current universal time in the default string format

# Importing the module for the function
#Import-Module "/Users/ssong/jcData/Modules/jcDataModule.psm1" # For local debugging only
Import-Module D:\home\site\wwwroot\Modules\jcDataModule.psm1
Get-Hello

# Connect to JC tenant
Connect-JCOnline -JumpCloudApiKey $env:JC_API_KEY -JumpCloudOrgId $env:JC_ORG_ID

# Getting the DI data
$dirOutData = Get-JCEvent -Service:('all') -StartTime:($backTrackingDate) -ErrorAction SilentlyContinue

if ($null -ne $dirOutData){
    
    Write-Host "Found $($dirOutData.count) events!"

    #exporting to blob
    $TempFile = New-TemporaryFile
    $dirOutData |ConvertTo-Json -Depth 100 | Out-File $TempFile

    $path = '/jcdataout/demodidata/'
    $customfilesuffix = "jcdi"
    out-blob -filename $tempfile.FullName -blobpath $path  -customfilesuffix $customfilesuffix

}
else {
    Write-Host "Found $($dirOutData.count) events! No activity for the on $backTrackingDate!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"