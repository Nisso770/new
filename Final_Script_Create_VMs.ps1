
# התחברות עם Managed Identity למנוי הנכון
Connect-AzAccount -Identity -AccountId "<Managed Identity ID>" -Subscription "<Subscription ID>"
# > הכנס את ה-Managed Identity ID (מזהה של Managed Identity שלך).
# > הכנס את ה-Subscription ID של המנוי שבו נמצאים המשאבים.

# משתנים כלליים
$resourceGroupname = "test_support"                # שם קבוצת המשאבים
$location = "West Europe"                         # מיקום (לדוגמה: "East US", "West Europe")
$hostpoolname = "test__support"                   # שם ה-Host Pool
$vnetName = "pavd-test-vnet"                      # שם ה-VNet
$subnetName = "default"                           # שם ה-Subnet
$vmsize = "D2ds_v5"                               # סוג ה-VM (לדוגמה: "Standard_DS1_v2")

# הגדרות ה-Image
$image = @{
    publisher = "microsoftwindowsdesktop"         # Publisher של ה-Image
    offer     = "windows-11"                      # Offer (לדוגמה: "windows-11")
    sku       = "win11-22h2-ent"                  # SKU (לדוגמה: "win11-22h2-ent")
    version   = "latest"                          # גירסה (השאר כ-"latest" לקבלת הגרסה העדכנית)
}

# פרטי מנהל מערכת
$adminUsername = "Mcs-admin-ryosef"               # שם משתמש של מנהל מערכת
$adminpass = ConvertTo-SecureString "Ryosef23" -AsPlainText -Force
# > הכנס את שם המשתמש והסיסמה עבור ה-VM.

# שליפת Subnet ID
$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupname -Name $vnetName).Subnets | Where-Object { $_.Name -eq $subnetName } | Select-Object -ExpandProperty Id
# > ודא ששם ה-VNet ($vnetName) ושם ה-Subnet ($subnetName) נכונים עבור הסביבה שלך.

# שליפת האינדקס ההתחלתי
$startIndex = (Get-AzWvdSessionHost -ResourceGroupName $resourceGroupname -HostPoolName $hostpoolname | Measure-Object).Count + 1

# לולאה ליצירת 5 מכונות והוספתן ל-Host Pool
1..5 | ForEach-Object {
    $vmname = "hostpoolvm-$startIndex"
    $startIndex++

    Write-Output "Creating VM: $vmname"

    # יצירת המכונה הווירטואלית
    New-AzVm -ResourceGroupName $resourceGroupname `
             -Location $location `
             -Name $vmname `
             -Size $vmsize `
             -Image $image `
             -Credential (New-Object PSCredential($adminUsername, $adminpass)) `
             -SubnetId $subnetId

    Write-Output "VM $vmname created successfully."

    # הוספת המכונה ל-Host Pool
    Add-AzWvdSessionHost -ResourceGroupName $resourceGroupname `
                         -HostPoolName $hostpoolname `
                         -SessionHostName $vmname `
                         -AllowNewSessionHost:$true

    Write-Output "Added $vmname to Host Pool $hostpoolname successfully."
}

Write-Output "All VMs created and added to the Host Pool successfully."
