#--------------------------------------------------------------------------------------
# Script:  QuerySQLAndInsertIntoELK.ps1
# Author:  German Taboadela/Franco Martin
# Date:  1/27/2019
# Version: 1.0
# Description: Sample script that can perform a query against a SQL server DB as input
# for an ELK server insertion. It supports multitenant implementation.
#--------------------------------------------------------------------------------------
#Parameters

param (
    [string]$ELKServer = "ELK01",
    [Parameter(Mandatory=$true)][string]$tenant
 )

## Modules required
Import-Module sqlserver

#This should be a separate powershell module to manage ELK actions.

$base = $elkServer 
$call = {
    param($verb, $params, $body)

    $uri = "http://$base`:9200"

   $headers = @{ 
        #user:pass base64 encoded
        'Authorization' = 'Basic cGFzc3dvcmQ='
    }

    Write-Host "`nCalling [$uri/$params]" -f Green
    if($body) {
        if($body) {
            Write-Host "BODY`n--------------------------------------------`n$body`n--------------------------------------------`n" -f Green
        }
    }

    $response = wget -Uri "$uri/$params" -method $verb -Headers $headers -ContentType 'application/json' -Body $body
    $response.Content
}

$get = {
    param($params)
    &$call "Get" $params
}

$delete = {
    param($params)
    &$call "Delete" $params
}

$put = {
    param($params,  $body)
    &$call "Put" $params $body
}

$post = {
    param($params,  $body)
    &$call "Post" $params $body
}

$cat = {
    param($json)

    &$get "_cat/indices?v&pretty"
}

$createIndex = {
    param($index, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$put $index $json
}

$add = {
    param($index, $type, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type" $json
}



#Examples of possible script uses

#Get all indices with:
#&$cat

#Create index example
<#
&$createIndex 'content!staging' -obj @{
    mappings = @{
        
            properties = @{
                selector = @{
                    type = "text"
                }
                title = @{
                    type = "text"
             }
            }      
    }
} #>


#Add Storage Entry


 switch ($tenant) {
        'Tenant1'{ 
            $sqlServerInstance="DB01"
            $folderPath="X:\Files01\Folder01"
                }
        'Tenant2'{
            $sqlServerInstance="DB02"
            $folderPath="X:\Files02\Folder01" }    
    }


$indexName="Index1-Log"
$folderDrive = (Split-Path -Path $folderPath -Qualifier).substring(0,1)
$diskData = Get-Volume -DriveLetter $folderDrive
$diskSize = $diskData.Size/1GB
$diskSizeRemaining = $diskData.SizeRemaining/1GB
$folderData=(Get-ChildItem $folderPath -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop)
[int]$folderSize=$folderData.Sum / 1MB
$files = $folderData.Count

#SQL Scripting
$getOrdersScriptPath=".\Query.sql"
$datarow= Invoke-Sqlcmd -InputFile $getOrdersScriptPath -ServerInstance $sqlServerInstance
$Date= $datarow.Item(0)
$Item= $datarow.Item(1)

#Insert everything into ELK

 &$add -index $indexName -type 'entry' -obj @{
        timeStamp = ([DateTime]::Now.ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.000000")
        sampleDate = [DateTime]::Now.ToString("yyyy-MM-dd")
        tenant = $tenant
        folder = $folderPath
        folderSize = $folderSize
        files = $files
        volumeSize = $diskSize
        volumeFreeSpace = $diskSizeRemaining 
        ordersCreated = $applications
        sqlSampleDate = $applicationsDate
   }
