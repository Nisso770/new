# Connect with Managed Identity to the correct subscription
Connect-AzAccount -Identity -AccountId "3b166040-15b3-459c-b68e-6f66ae8ecd5d" -subscription "31076e3c-fc5e-4f0b-be52-0eb744e89036"

#import-module Az
# Get all VMs from the right size which are running in any DEV RG-AVDs (AWS + GCP)
$vms_AWS_dev= Get-AzVM -ResourceGroupName AVD-Dev-RG -Status | Where-Object {$_.PowerState -eq "VM running"}
Write-Output $vms_AWS_dev.Name
$vms_GCP_dev= Get-AzVM -ResourceGroupName AVD-9900-Dev-RG -Status | Where-Object {$_.PowerState -eq "VM running"}
Write-Output $vms_GCP_dev.Name


# For AWS DEV's AVDs
foreach ($vm in $vms_AWS_dev){
    # Run command in runcommand
    Invoke-AzVMRunCommand -VMName $vm.Name -ResourceGroupName AVD-Dev-RG -CommandId RunPowerShellScript -ScriptString '$AvailableUsers = (Get-ChildItem c:\users -Directory | Where-Object {($_.Name -ne "Public") -and ($_.Name -ne "defaultuser0")}).Name 
    Start-Sleep -Seconds 30
    # Allow all azuread managed users who logged into the computer to use Docker for Windows:
    foreach($User in $AvailableUsers){
        add-LocalGroupMember -Group docker-users -Member "azuread\$User"
    }
    '
}

# For GCP DEV's AVDs
foreach ($vm in $vms_GCP_dev){
    # Run command in runcommand
    Invoke-AzVMRunCommand -VMName $vm.Name -ResourceGroupName AVD-9900-Dev-RG -CommandId RunPowerShellScript -ScriptString '$AvailableUsers = (Get-ChildItem c:\users -Directory | Where-Object {($_.Name -ne "Public") -and ($_.Name -ne "defaultuser0")}).Name 
    Start-Sleep -Seconds 30
    # Allow all azuread managed users who logged into the computer to use Docker for Windows:
    foreach($User in $AvailableUsers){
        add-LocalGroupMember -Group docker-users -Member "azuread\$User"
    }
    '
}
