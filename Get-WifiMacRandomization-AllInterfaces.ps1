# Show MAC Randomization State for All Wireless Interfaces
# v 0.1

# Get all Wi-Fi interface GUIDs
$wifiAdapters = Get-NetAdapter -Physical | Where-Object {$_.InterfaceDescription -match "Wi-Fi|Wireless"}

foreach ($adapter in $wifiAdapters) {
    $guid = $adapter.InterfaceGuid
    $regPath = "HKLM:\SOFTWARE\Microsoft\WlanSvc\Interfaces\$guid"
#    $status = Get-ItemProperty -Path $regPath -Name RandomMacState -ErrorAction SilentlyContinue | Select-Object -ExpandProperty RandomMacState -ErrorAction SilentlyContinue
    $status = (Get-ItemProperty -Path $regPath -Name RandomMacState `
            -ErrorAction SilentlyContinue).RandomMacState

    # normalize $status from binary to an integer
    if ($status -is [byte[]]) {
        $status = [int]$status[0]        # first byte => 0 or 1
    }

    # if the value is missing, treat as 0
    if ($null -eq $status) {
        $status = 0
    }

    # it is very likely that "2" is not a valid option for RandomMacState
    switch ($status) {
        1 { $desc = "ENABLED (new networks only)" }
        2 { $desc = "ENABLED (all networks)" }
        0 { $desc = "DISABLED" }
        default { $desc = "DISABLED (or not set)" }
    }
    Write-Host "$($adapter.Name) (GUID: $guid): MAC Randomization is $desc`n"
}
