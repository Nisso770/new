
# התחברות עם Managed Identity
Write-Output "Starting script - connecting to Azure with Managed Identity..."
try {
    Connect-AzAccount -Identity -AccountId "<Managed Identity ID>" -Subscription "<Subscription ID>"
    Write-Output "Successfully connected to Azure."
} catch {
    Write-Error "Failed to connect to Azure with Managed Identity. Check the Managed Identity ID and Subscription ID."
    throw $_
}

# משתנים כלליים
$resourceGroupname = "test_support"
$location = "West Europe"
$hostpoolname = "test__support"
$vnetName = "pavd-test-vnet"
$subnetName = "default"
$vmsize = "D2ds_v5"

Write-Output "Parameters loaded:
- Resource Group: $resourceGroupname
- Location: $location
- Host Pool: $hostpoolname
- VNet: $vnetName
- Subnet: $subnetName
- VM Size: $vmsize"

# הגדרות ה-Image
$imageReference = @{
    Publisher = "microsoftwindowsdesktop"
    Offer     = "windows-11"
    Sku       = "win11-22h2-ent"
    Version   = "latest"
}
Write-Output "Image parameters loaded: $($imageReference | Out-String)"

# פרטי מנהל מערכת
$adminUsername = "Mcs-admin-ryosef"
$adminpass = ConvertTo-SecureString "Ryosef23" -AsPlainText -Force
$adminCredentials = New-Object PSCredential($adminUsername, $adminpass)
Write-Output "Admin credentials prepared."

# שליפת Subnet ID
Write-Output "Fetching Subnet ID for VNet: $vnetName and Subnet: $subnetName..."
try {
    $subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupname -Name $vnetName).Subnets | 
                 Where-Object { $_.Name -eq $subnetName } | 
                 Select-Object -ExpandProperty Id
    if (-not $subnetId) {
        throw "Subnet ID not found for VNet: $vnetName and Subnet: $subnetName."
    }
    Write-Output "Subnet ID fetched successfully: $subnetId"
} catch {
    Write-Error "Failed to fetch Subnet ID. Ensure the VNet and Subnet names are correct."
    throw $_
}

# שליפת האינדקס ההתחלתי
Write-Output "Fetching initial index for Host Pool: $hostpoolname..."
try {
    $startIndex = (Get-AzWvdSessionHost -ResourceGroupName $resourceGroupname -HostPoolName $hostpoolname | Measure-Object).Count + 1
    Write-Output "Initial index fetched: $startIndex"
} catch {
    Write-Error "Failed to fetch initial index for Host Pool. Ensure the Host Pool name is correct."
    throw $_
}

# לולאה ליצירת 5 מכונות והוספתן ל-Host Pool
1..5 | ForEach-Object {
    $vmname = "hostpoolvm-$($startIndex++)-$(Get-Date -Format 'yyyyMMddHHmmss')"
    Write-Output "Starting creation of VM: $vmname"

    try {
        # יצירת המכונה הווירטואלית
        New-AzVm -ResourceGroupName $resourceGroupname `
                 -Location $location `
                 -Name $vmname `
                 -Size $vmsize `
                 -ImageReference $imageReference `
                 -Credential $adminCredentials `
                 -SubnetId $subnetId
        Write-Output "VM $vmname created successfully."
    } catch {
        Write-Error "Failed to create VM $vmname. Check the parameters and resource availability."
        continue
    }

    try {
        # הוספת המכונה ל-Host Pool
        Write-Output "Adding VM $vmname to Host Pool $hostpoolname..."
        Add-AzWvdSessionHost -ResourceGroupName $resourceGroupname `
                             -HostPoolName $hostpoolname `
                             -SessionHostName $vmname `
                             -AllowNewSessionHost:$true
        Write-Output "Added $vmname to Host Pool $hostpoolname successfully."
    } catch {
        Write-Error "Failed to add VM $vmname to Host Pool. Check the Host Pool parameters and VM status."
    }
}

Write-Output "Script completed: All tasks processed."
