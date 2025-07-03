# Show MAC Randomization State for All Wireless Profiles on all Wi-Fi Interfaces
# v 0.1
#
# -Enabled = show only profiles with MAC randomization enabled 
# -Disabled = show only profiles with MAC randomization disabled 
#
param(
    [switch]$Enabled,
    [switch]$Disabled
)

if ($Enabled -and $Disabled) {
    Write-Error "Specify only one of -Enabled or -Disabled."
    exit 1
}

$root = 'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces'

$profiles = Get-ChildItem -Path $root -Filter *.xml -Recurse -ErrorAction SilentlyContinue

if (-not $profiles) {
    Write-Host "No Wi-Fi profile XML files found under $root.`n" -ForegroundColor Yellow
    exit 0
}

Write-Host "" -nonewline
if ($Enabled) {
    Write-Host "Showing only Wi-Fi Profiles with MAC Randomization ENABLED."
} elseif ($Disabled) {
    Write-Host "Showing only Wi-Fi Profiles with MAC Randomization DISABLED."
} else {
    Write-Host "Showing all Wi-Fi Profiles"
}

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

        # Assess MAC randomization status (no changes made)
        $state = 'undefined (disabled)'

        if ($macRand) {
          
            $enableNode = $macRand.ChildNodes | Where-Object { $_.LocalName -eq 'enableRandomization' }

            if ($enableNode) {
                $state = ($enableNode.InnerText -eq 'true') ? 'enabled' : 'disabled'
            }
        }

        if ( ($Enabled  -and $state -ne 'enabled') -or
             ($Disabled -and $state -ne 'disabled') ) {
            return   # skip, user doesn't want to see this profile
        }
        
        Write-Host "[$state] $($_.Name) - " -NoNewline
        Write-Host $ssid -ForegroundColor Yellow

        $shown++
        
    } catch {
        Write-Warning "[Failed] $($_.Name) - $ssid - $_"
    }
}

if ($shown -eq 0) {
    Write-Host "No profiles matched the specified filter.`n" -ForegroundColor Yellow
}
Write-Output ""