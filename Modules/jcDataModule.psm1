
function Get-Hello {
   Write-Output "Shawn's Function says Hello!"
    
}
function Invoke-SysinsightApi{
   
   Param(
    $apiep,
    $apikey
   )
   $url = "https://console.jumpcloud.com/api/v2/systeminsights/"
   $limit = 1000
   $skip = 0
   $header = @{
      'x-api-key' = $apikey
   }
   $hasmore = $true
   $apiepdataout = @()
   $apiepdata = @()
   $currentUTCtime = (Get-Date).ToUniversalTime()
   do{
      $api = $url + $apiep +'?limit=' + $limit + '&skip=' + $skip
      $apiepdata = Invoke-RestMethod -Method Get -Uri $api -Headers $header
      $apiretry = 3
      if (("" -eq $apiepdata) -and ($limit -eq 1000)){
         do{
            sleep 10
            Write-Information "Retrying $api, for $apiretry time..."
            $apiepdata = Invoke-RestMethod -Method Get -Uri $api -Headers $header
            $apiretry -= 1
         }while ($apiretry > 0)
      }
      
      Write-Information "fetching $($apiepdata.count) records, $($apiepdataout.count) records collected so far!"
      Write-Information "Total runtime $($runtime.hours) hours $($runtime.Minutes) Minutes $($runtime.Seconds) Seconds"
      
      $runtime = $(Get-Date).ToUniversalTime() - $currentUTCtime
      $skip += $limit
      $apiepdataout += $apiepdata
      

      #loop breaking
      if ("" -eq $apiepdata){
         $hasmore = $false
         Write-Information "Total $($apiepdataout.count) collected!"
      }

   }while ($hasmore -eq $true)
 
   return $apiepdataout

}

function Invoke-DirInsightApi {
   param (
      $days=0,
      $apikey,
      $service='all',
      [Parameter(Mandatory=$false)][bool]$search = $false,
      [Parameter(Mandatory=$false)][string]$condition = 'and',
      [Parameter(Mandatory=$false)][array]$searchterm
   )

   $currentUTCtime = (Get-Date).ToUniversalTime()
   $timeformat = "yyyy-MM-ddT00:00:00.000Z"

   $starttime = $currentUTCtime.AddDays(-($days+1)).ToString($timeformat)
   $endtime = $currentUTCtime.adddays(-$days).ToString($timeformat)
   Write-Information "Getting data from $starttime to $endtime"

   $dirOutData = @()
   $url = "https://api.jumpcloud.com/insights/directory/v1/events"
   $header = @{
      'x-api-key' = $apikey
   }
   $body = @{
      service = @(
         $service
      )
      start_time = $starttime
      end_time = $endtime
   }|ConvertTo-Json

   do{
      $hasmore = $true
      $dirData = Invoke-RestMethod -Method Get -Uri $url -Body $body -Headers $header -ResponseHeadersVariable feedback 

      #retry if timeout / connection reset
      $apiretry = 3
      if (("" -eq $dirdata) -and ($limit -eq 1000)){
          do{
              sleep 10
              Write-Information "Retrying $api, for $apiretry time..."
              $dirdata = Invoke-RestMethod -Method Get -Uri $url -Body $body -Headers $header -ResponseHeadersVariable feedback
              $apiretry -= 1
          }while ($apiretry > 0)
      }
      $resultcount = $feedback.'X-Result-Count' |ConvertFrom-Json
      $resultlimit = $feedback.'X-Limit' | ConvertFrom-Json
      $searchafter = $feedback.'X-Search_after' | ConvertFrom-Json
      #reconstuct the body with search_after value for pagination
      $body = @{
          service = @(
              "all"
          )
          start_time = $starttime
          end_time = $endtime
          search_after = @(
              $searchafter
          )
      }|ConvertTo-Json       
  
      Write-Information "collecting batch of $resultcount, total $($diroutdata.count)"
      if($resultcount -lt $resultlimit){
          $hasmore = $false
          Write-Information "Total $($diroutdata.count) of records collected"
      }
      $dirOutData += $dirData
      $runtime = $(Get-Date).ToUniversalTime() - $currentUTCtime
      Write-Information "Total runtime $($runtime.hours) hours $($runtime.Minutes) Minutes $($runtime.Seconds) Seconds" 
      Write-Information "current $searchafter id"
  }while($hasmore -eq $true)

  return $dirOutData
}
function Out-Blob {
   param (
      $blobpath,
      $filename,
      [Parameter(Mandatory=$false)][string]$apiep,
      [Parameter(Mandatory=$false)][string]$customfilesuffix,
      [Parameter(Mandatory=$false)][bool]$datefolders = $false

   )
   $currentUTCtime = (Get-Date).ToUniversalTime()
   $timeformat = "yyyy-MM-dd-HHmm"

   if("" -ne $apiep){
      $addpath = $apiep+'/'
      $filesuffix = $apiep+'_'
   }
   elseif ("" -ne $customfilesuffix) {
      $filesuffix = $customfilesuffix + '_'
   }

   if ($datefolders){
      $datefolder = $currentUTCtime.ToString("yyyy-MM-dd") + '/'
   }
   else {
      $datefolder = $null
   }

   $blob = $blobpath + $addpath + $datefolder + $filesuffix +$currentUTCtime.ToString($timeformat)+'.json'
   $ctx = New-AzStorageContext -ConnectionString $env:AzureWebJobsStorage
   Write-Information "generating $blob"
   Set-AzStorageBlobContent -File $filename -Container $env:ContainerName -Blob $blob -Context $ctx -Force
}