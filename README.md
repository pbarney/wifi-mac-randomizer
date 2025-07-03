# Wi-Fi MAC Randomization Enabler (Windows 10/11)

## SYNOPSIS
`Enable-WiFiMacRandomization-AllProfiles.ps1` is a Powershell 7 script for Windows 10/11 systems that ensures that hardware address (MAC) randomization is turned on for your wi-fi interfaces and that all existing Wi-Fi profiles have Hardware (MAC) address randomization enabled.

## DESCRIPTION
If you've joined multiple Wi-Fi networks prior to turning on `Random Hardware Addresses` in the Windows settings, your old profiles will still be set to use the default MAC address, which is probably not what you want.

Your choices are to either:
1. remove all of the previous Wi-Fi networks, or
2. manually edit the properties of each network to turn on hardware address (MAC) randomization.

The script gives you an alternative: **It will turn on hardware address (MAC) randomization for all existing Wi-Fi profiles**, regardless of their current setting.

This script requires Administrator privileges, and AS ALWAYS, BACK UP THE PROFILE DIRECTORY BEFORE RUNNING.

### Details:
In order for Hardware address (MAC) randomization to work, it will need to be turned on at the system level (`RandomMacState` in the registry or the "Use random hardware addresses" setting in the Settings GUI), and also for each wi-fi profile on your system (`MacRandomization` in each wi-fi profile's XML file).

If the system-level setting is not turned on, the script will offer you the option of turning it on for each wi-fi interface.

The script will then scan all Wi-Fi profile XML files under `C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces\` and ensure that each profile has MAC randomization turned on (that it contains a `<MacRandomization>` element with `<enableRandomization>` set to `true` and a randomly-generated `<randomizationSeed>` if not already set).

After processing, the script will offer to restart the WLAN AutoConfig service ('WlanSvc') to apply changes.

## Scripts
- **`Enable-WiFiMacRandomization-AllProfiles.ps1`** - **The only script you need.** It will do all of the functionality above.
- `Enable-WifiMacRandomization-AllInterfaces.ps1` - A stand-alone script to turn on the system-level `RandomMacState` for all wi-fi interfaces.
- `Get-WifiMacRandomization-AllInterfaces.ps1` - Shows the system-level `RandomMacState` setting for each wi-fi interface on your system. 
- `Get-WifiMacRandomization-AllProfiles.ps1` - Shows the `MacRandomization` state for each wi-fi profile on your system. 

