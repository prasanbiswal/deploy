using namespace System.Net

# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

$date = get-date -format "dd-MMM-yyyy"
#File name for the VM Usage file
$Filename = "Subscriptions-"+$date+".csv"
$allSubs = Get-AzSubscription
$result1 =@()
$result1=foreach($Sub in $allSubs)
{
Set-AzContext -Subscription $Sub | Out-Null
$Sub = Get-AzContext
$ResourceID = "/Subscriptions/" + $Sub.Subscription
$result = Get-AzTag -ResourceId $ResourceID
$Tags = $result.Properties.TagsProperty
###################Setting Maximum Length#####################
[int]$len=($Tags.count | Measure-Object -Maximum).Maximum
for($i=0;$i -lt $len;$i++)
{
##############################Displaying tags##########################
    if($Tags.Count -gt 1)
    {
        $TagName  = ($Tags.Keys -split "`n")[$i]
        $TagValue = ($Tags.Values -split "`n")[$i]
    }
    elseif($Tags.Count -eq 1)
    {
        $TagName  = $Tags.Keys
        $TagValue = $Tags.Values
        $Tags='1'
    }
    else
    {
        $TagName  = $null
        $TagValue = $null
    }
'' | Select @{n='Subscription Name';e={$Sub.Name}},@{n='SubscriptionID';e={$Sub.Subscription}},@{n='TagName';e={$TagName}},@{n='TagValue';e={$TagValue}}
}
}
$result1 |  Export-Csv  -Path  $env:temp\$Filename  -Append -NoTypeInformation -force
Select-AzSubscription -Subscription "GOInfra Sandbox"
$storageAccount = Get-AzStorageAccount -Name 'storageaccounttstsiab3f' -ResourceGroupName tstsisrg
$storageKey = (Get-AZStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
$containerName = "subscriptiondata"
$context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
#Uploading the files to the container
Set-AzStorageBlobContent -Container $containerName  -File  $env:temp\$Filename   -Blob "$Filename" -Context $context -force
$runningVmsHTML = $result1 | ConvertTo-Html -property "Subscription Name", "SubscriptionID", "TagName", "TagValue"

Push-OutputBinding -Name Response -Value (@{
        StatusCode  = "ok"
        ContentType = "text/html"
        Body        = $runningVmsHTML 
    })
