<#
.SYNOPSIS
    Ensures all existing Wi-Fi profiles have Hardware (MAC) address 
    randomization enabled on Windows 10/11 systems.

.DESCRIPTION
    If you've joined multiple Wi-Fi networks prior to turning on `Random 
    Hardware Addresses` in the Windows settings, your old profiles will still 
    be set to use the default MAC address, which is probably not what you want.
    
    Your choices are to either remove all of the previous Wi-Fi networks, or to 
    manually edit the properties of each network to turn on hardware address 
    (MAC) randomization.
    
    The script gives you an alternative: It will turn on hardware address (MAC) 
    randomization for all existing Wi-Fi profiles, regardless of their current 
    setting.
    
    This script requires Administrator privileges.
    - AS ALWAYS, BACK UP THE PROFILE DIRECTORY BEFORE RUNNING.
    
    Details:
    
    If the "Use random hardware addresses" setting is not turned on, it will 
    offer you the option of turning it on.
    
    The script scans all Wi-Fi profile XML files in 
    'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces\' and ensures that 
    each profile contains a <MacRandomization> element with 
    <enableRandomization> set to true and a randomly-generated 
    <randomizationSeed> (if not already set).
    
    After processing, the script offers to restart the WLAN AutoConfig service 
    ('WlanSvc') to apply changes.

.NOTES

    Author: pbarney at github
    Last Edit: 2025-07-02
    Version: 0.1 - 2025-07-02 - initial release
    Version: 0.2 - 2025-07-03 - ask user if they wish to enable randomization 
                                on each wifi interface

#>

# Ensure script runs as administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Error "You must run this script as Administrator."
    Exit 1
}

$root = 'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces'
$macNs = "http://www.microsoft.com/networking/WLAN/profile/v3"

Function Get-RandomDword {
    $bytes = New-Object byte[] 4
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [BitConverter]::ToUInt32($bytes,0)
}

# Ensure script runs as administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Error "You must run this script as Administrator."
    Exit 1
}

# List Wi-Fi adapters and make sure that MAC Randomization is enabled for each
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
        Write-Host "$($adapter.Name): MAC Randomization system setting is already enabled."
    }
}

# Recurse through all Wi-Fi profiles in the $root directory and enabled MAC Randomization
$profiles = Get-ChildItem -Path $root -Filter *.xml -Recurse -ErrorAction SilentlyContinue

$lastGuid = $null

$profiles | ForEach-Object {
  
    $guid = $_.Directory.Name          # interface GUID taken from path

    if ($guid -ne $lastGuid) {
        $adapter = Get-NetAdapter -Physical |
                   Where-Object { $_.InterfaceGuid -eq $guid }

        $name = if ($adapter) { $adapter.Name } else { '(unknown adapter)' }
        Write-Host "`n=== Interface: $name  [$guid] ===" -ForegroundColor Cyan
        $lastGuid = $guid
        $shown = 0
    }

    $file = $_.FullName
    try {
        [xml]$xml = Get-Content $file -Raw
        
        # Obtain the SSID for the network to display it for the user during output
        $ssid = $null
        try {
            # Try to handle possible namespaces (most profiles use a default namespace)
            $ns = $xml.DocumentElement.NamespaceURI
            if ($ns) {
                $mgr = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
                $mgr.AddNamespace("ns", $ns)
                $ssid = $xml.SelectSingleNode('//ns:SSIDConfig/ns:SSID/ns:name', $mgr).InnerText
            } else {
                $ssid = $xml.SelectSingleNode('//SSIDConfig/SSID/name').InnerText
            }
        } catch {
            $ssid = '(unknown SSID)'
        }
        
        $docElement = $xml.DocumentElement

        # Find existing MacRandomization, regardless of namespace
        $macRand = $null
        foreach ($node in $docElement.ChildNodes) {
            if ($node.LocalName -eq 'MacRandomization') {
                $macRand = $node
                break
            }
        }

        if ($macRand) {
            # Update or add <enableRandomization> within existing MacRandomization
            $foundEnable = $false
            foreach ($child in $macRand.ChildNodes) {
                if ($child.LocalName -eq 'enableRandomization') {
                    $child.InnerText = 'true'
                    $foundEnable = $true
                }
            }
            if (-not $foundEnable) {
                $enableRand = $xml.CreateElement("enableRandomization", $macNs)
                $enableRand.InnerText = 'true'
                $macRand.AppendChild($enableRand) | Out-Null
            }
            # Optionally, ensure MacRandomization uses the correct namespace 
            # (unlikely to fail, and requires more work to fix)
            if ($macRand.NamespaceURI -ne $macNs) {
                Write-Warning "Warning: MacRandomization in $file has unexpected namespace. Manual review may be needed."
            }
        } else {
            # Create new MacRandomization with required elements
            $macRand = $xml.CreateElement("MacRandomization", $macNs)
            $enableRand = $xml.CreateElement("enableRandomization", $macNs)
            $enableRand.InnerText = 'true'
            # According to the XML XSD for the <WLANProfile> element, 
            # https://learn.microsoft.com/en-us/windows/win32/nativewifi/wlan-profileschema-wlanprofile-element
            # the order of elements matters, so if <MacRandomization> doesn't 
            # exist, it will be created as the last element within the 
            # <WLANProfile> element, as per spec. If the spec sequence changes,
            # we will need to use InsertBefore/InsertAfter relative to another 
            # anchor element (such as <MSM>
            $macRand.AppendChild($enableRand) | Out-Null
            $seed = $xml.CreateElement("randomizationSeed", $macNs)
            $seed.InnerText = (Get-RandomDword).ToString()
            $macRand.AppendChild($seed) | Out-Null
            $docElement.AppendChild($macRand) | Out-Null
        }

        $xml.Save($file)
        Write-Host "Patched: $($_.Name) - " -NoNewline
        Write-Host $ssid -ForegroundColor Yellow
        
    } catch {
        Write-Warning "Failed to process: $($_.Name)  ($ssid) - $_"
    }
}

# Ask user if they want to restart the WLAN service
$prompt = Read-Host "Do you want to restart the WLAN AutoConfig service now? (Y/N)"
if ($prompt -match '^[Yy]') {
    try {
        Restart-Service WlanSvc -ErrorAction Stop
        Write-Host "WLAN AutoConfig service restarted."
    } catch {
        Write-Warning "Failed to restart WlanSvc: $_"
    }
} else {
    Write-Host "Note: Your changes may not take effect until you restart the WLAN AutoConfig service (WlanSvc) or reboot your computer."
}
