$Title = "Exchange 20xx Basic Server Information"
$Header ="Exchange 20xx Basic Server Information"
$Comments = "Exchange 20xx Basic Server Information"
$Display = "Table"
$Author = "Phil Randal"
$PluginVersion = 2.3
$PluginCategory = "Exchange2010"

# Based on http://www.mikepfeiffer.net/2010/03/exchange-2010-database-statistics-with-powershell/
#          http://blog.jasonsherry.net/2012/12/27/get-exchangever/

# Start of Settings
# End of Settings

#Changelog
## 2.0 : Exchange 2007 support
## 2.1 : Fail hotfix check gracefully if remote registry not available
##     : Add Server name filter
## 2.2 : Sort rollups by install date
## 2.3 : Get Exchange 2013 rollup info 

If ($2007Snapin -or $2010Snapin) {
  $exServers = Get-ExchangeServer -ErrorAction SilentlyContinue |
    Where { $_.IsExchange2007OrLater -eq $True -and $_.Name -match $exServerFilter } |
	Sort Name
  If ($exServers -ne $null) {
    Foreach ($exServer in $exServers) {
      $Target = $exServer.Name
      Write-CustomOut "...Collating Server Details for $Target"
#      Write-CustomOut "....getting basic computer configuration"
	  $ComputerSystem = Get-WmiObject -computername $Target Win32_ComputerSystem
	  $OperatingSystems = Get-WmiObject -computername $Target Win32_OperatingSystem
	  $TimeZone = Get-WmiObject -computername $Target Win32_Timezone
	  $Keyboards = Get-WmiObject -computername $Target Win32_Keyboard
	  $SchedTasks = Get-WmiObject -computername $Target Win32_ScheduledJob
	  $BootINI = $OperatingSystems.SystemDrive + "boot.ini"
	  $RecoveryOptions = Get-WmiObject -computername $Target Win32_OSRecoveryConfiguration
	  $exVersion = $exServer.AdminDisplayVersion
	  $exVer = ""
	  If ($exVersion -match "Version 8") {
	    $exVer = "8"
	  } ElseIf ($exVersion -match "Version 14") {
	    $exVer = "14"
	  } ElseIf ($exVersion -match "Version 15") {
	    $exVer = "15"
	  }
	  #$exVersion = "Version " + $exVer + "." + $exServer.AdminDisplayVersion.Minor + " (Build " + $exServer.AdminDisplayVersion.Build + "." + $exServer.AdminDisplayVersion.Revision + ")"

#	  Write-CustomOut "....getting Exchange rollup information"
	  If ($exVer -eq "8" -or $exVer -eq "14" -or $exVer -eq "15") {
	    Switch ($exVer) {
	      "8"  { $rollUpKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\461C2B4266EDEF444B864AD6D9E5B613\\Patches" }
		  "14" { $rollUpKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\AE1D439464EB1B8488741FFA028E291C\\Patches" }
		  "15" { $rollUpKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData\\S-1-5-18\\Products\\AE1D439464EB1B8488741FFA028E291C\\Patches" }
	    }
	  }
      $Rollups = "Unknown"
	  $InstDates = ""
      $registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $target)
	  If ($Registry) {
        $installedRollUps = $registry.OpenSubKey($rollUpKey).GetSubKeyNames()
 		$ru = @()
	    foreach ($rollUp in $installedRollUps) {
          $thisRollUp = "$rollUpKey\\$rollUp"
		  $ru += New-Object PSObject -Property @{
		    Date = $thisRollUp | %{$registry.OpenSubKey($_).getvalue('Installed')}
		    Name = $thisRollUp | %{$registry.OpenSubKey($_).getvalue('DisplayName')}
		  }
		}
        $Rollups = ""
		ForEach ($rollup in ($ru | Sort Date)) {
          $Rollups += $rollup.Name + ", "
          $InstDates += $rollup.Date + ", "
		}
      }
	  $LBTime=$OperatingSystems.ConvertToDateTime($OperatingSystems.Lastbootuptime)
	  $Result=New-Object PSObject -Property @{
		"Computer Name" = $ComputerSystem.Name
		"Operating System" = $OperatingSystems.Caption
		"Service Pack" = $OperatingSystems.CSDVersion
		"Exchange Version" = $exVersion
		"Rollups" = $Rollups -replace '(.*), $','$1'
		"Rollup Install Dates" = $InstDates -replace '(.*), $','$1'
		"Exchange Edition" = $exServer.Edition
		"Exchange Role(s)" = $exServer.ServerRole
	  }
	  If ($Result -ne $null) {
	    $Result |
          Select "Computer Name",
		    "Operating System",
			"Service Pack",
			"Exchange Version",
			"Rollups",
			"Rollup Install Dates",
			"Exchange Edition",
			"Exchange Role(s)"
	  }
	}
  }
}
