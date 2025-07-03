# Prompt User and Conditionally Enable 
# v 0.1

# Ensure script runs as administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Error "You must run this script as Administrator."
    Exit 1
}

# List Wi-Fi adapters
$wifiAdapters = Get-NetAdapter -Physical | Where-Object {$_.InterfaceDescription -match "Wi-Fi|Wireless"}

foreach ($adapter in $wifiAdapters) {
    $guid = $adapter.InterfaceGuid
    $regPath = "HKLM:\SOFTWARE\Microsoft\WlanSvc\Interfaces\$guid"
    $status = Get-ItemProperty -Path $regPath -Name RandomMacState -ErrorAction SilentlyContinue | Select-Object -ExpandProperty RandomMacState -ErrorAction SilentlyContinue
    if ($null -eq $status) { $status = 0 }
    $enabled = ($status -eq 1)
    if (-not $enabled) {
        Write-Host "`nAdapter: $($adapter.Name) (GUID: $guid)"
        $answer = Read-Host "MAC Randomization is DISABLED. `nYou need to enable it if you want to hide your hardware address from Wi-Fi networks. `nWould you like to enable it for this adapter? (Y/N)"
        if ($answer -match '^(y|yes)$') {
            Set-ItemProperty -Path $regPath -Name RandomMacState `
                             -Type Binary -Value ([byte[]](0x01,0x00,0x00,0x00))
            Write-Host "MAC Randomization enabled for $($adapter.Name)."
        } else {
            Write-Host "WARNING: MAC Randomization will not work on this adapter until you enable it."
            # (continue script...)
        }
    } else {
        Write-Host "$($adapter.Name): MAC Randomization is already enabled."
    }
}
