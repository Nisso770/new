# התחברות עם Managed Identity
$managedidentity = "7e0ec116-0d45-4ced-80d1-117df984320a"
Connect-AzAccount -Identity -AccountId $managedidentity

# משתנים כלליים
$resourceGroupname = "test_support"
$location = "Israel Central"
$hostpoolname = "test__support"
$vnetName = "pavd-test-vnet"
$subnetName = "default"
$vmsize = "D2lds_v5"
$subnetId = "/subscriptions/31076e3c-fc5e-4f0b-be52-0eb744e89036/resourceGroups/test_support/providers/Microsoft.Network/virtualNetworks/pavd-test-vnet/subnets/default"

# הגדרות ה-Image
$imageReference = @{
    Publisher = "microsoftwindowsdesktop"
    Offer     = "windows-11"
    Sku       = "win11-22h2-ent"
    Version   = "latest"
}

Write-Output "Image parameters loaded: $($imageReference | Out-String)"
Write-Output "Parameters loaded:
- Resource Group: $resourceGroupname
- Location: $location
- Host Pool: $hostpoolname
- VNet: $vnetName
- Subnet: $subnetName
- VM Size: $vmsize
- SubnetId: $subnetId
- Image: $imageReference"

# פרטי מנהל
$adminUsername = "Mcs-admin-ryosef"
$adminpass = ConvertTo-SecureString "Ryosef23" -AsPlainText -Force
$adminCredentials = New-Object PSCredential($adminUsername, $adminpass)
Write-Output "Admin credentials prepared."

# שליפת האינדקס ההתחלתי
Write-Output "Fetching initial index for Host Pool: $hostpoolname..."
try {
    $startIndex = (Get-AzWvdSessionHost -ResourceGroupName $resourceGroupname -HostPoolName $hostpoolname | Measure-Object).Count + 1
    Write-Output "Initial index fetched: $startIndex"
} catch {
    Write-Error "Failed to fetch initial index for Host Pool. Ensure the Host Pool name is correct."
    throw $_
}

# יצירת שם ה-VM
$vmname = "hostpoolvm-$($startIndex)-$(Get-Date -Format 'yyMMddHHmmss')"  
Write-Output "Starting creation of VM: $vmname"

try {
    # יצירת NIC
    Write-Output "Creating Network Interface for VM $vmname..."
    $nic = New-AzNetworkInterface -Name "$vmname-NIC" -ResourceGroupName $resourceGroupname -Location $location -SubnetId $subnetId
    # NIC זה **לא מקבל Public IP**

    # יצירת ה-VM
    Write-Output "Creating VM $vmname in Resource Group: $resourceGroupname - Location: $location"
    $vmConfig = New-AzVMConfig -VMName $vmname -VMSize $vmsize
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmname -Credential $adminCredentials
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $imageReference.Publisher -Offer $imageReference.Offer -Skus $imageReference.Sku -Version $imageReference.Version
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    # יצירת Boot Diagnostics
    Write-Output "Enabling Boot Diagnostics for VM $vmname..."
    $bootDiagnostics = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.BootDiagnostics
    $bootDiagnostics.Enabled = $true
    $bootDiagnostics.StorageUri = "https://roystorge.blob.core.windows.net/bootdiagnostics"

    # הגדרת Boot Diagnostics ל-VM
    $vmConfig = Set-AzVM -VM $vmConfig -BootDiagnostics $bootDiagnostics

    # יצירת ה-VM בפועל
    New-AzVM -ResourceGroupName $resourceGroupname -Location $location -VM $vmConfig
    Write-Output "VM $vmname created successfully."

    # הוספת ה-VM ל-Host Pool
    Write-Output "Adding VM $vmname to Host Pool $hostpoolname..."
    Import-Module Az.DesktopVirtualization

    Add-AzWvdSessionHost -ResourceGroupName $resourceGroupname `
                          -HostPoolName $hostpoolname `
                          -SessionHostName $vmname `
                          -AllowNewSessionHost $true

    Write-Output "Added VM $vmname to Host Pool $hostpoolname successfully."
} catch {
    Write-Error "Failed to create or add VM $vmname. Error: $_"
}
