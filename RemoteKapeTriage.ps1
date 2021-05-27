<#
.SYNOPSIS
Executes Kape and Kape modules on a remote device and archives output.

.DESCRIPTION
Collects forensic information from a remote machine.
 
.PARAMETER target
-target 
The device to investigate.

.PARAMETER Collect
-collect
Data to collect. basic, basic+, medium, medium+, full, full+, memdump

.PARAMETER fileshare
-save default value are defined with $fileshare variable, but could be specified at command execution
for optional location to save forensic data.

.EXAMPLE 
RemoteKapeTriage.ps1 -ComputerName Win10Desktop -Collect Basic

.EXAMPLE
RemoteKapeTriage.ps1 -ComputerName Win10Desktop -Collect Basic+ -fileshare \\forensic-server\c$\

.AUTHOR
Author: Richard Arias - https://github.com/Richard1611
Credits for: "Keyboardcrunch" who giveme some ideas about switch/arguments systems without even know it https://github.com/keyboardcrunch/Invoke-Kape

#>
[CmdLetBinding()]
param(
    [switch]$help,   
    [string]$kapelocalpath = "C:\kape\kape\",
    [string]$kapelocalfile = "kape.exe",    
    [string]$target, #= $(throw "-target is required. For help use arguments -target -help"),
    [string]$fileshare = "\\forense01.corp.popular.local\j$\triagetools",
    [string]$KapePackage = "$fileshare\kape.zip",
    [string]$Collect #= $(throw "-collect is required. For help, use -collect -help")
)

$ErrorActionPreference = "Continue"

$Banner = "
 ____  _____ __  __  ___ _____ _____   _  __    _    ____  _____  
|  _ \| ____|  \/  |/ _ \_   _| ____| | |/ /   / \  |  _ \| ____| 
| |_) |  _| | |\/| | | | || | |  _|   | ' /   / _ \ | |_) |  _|   
|  _ <| |___| |  | | |_| || | | |___  | . \  / ___ \|  __/| |___  
|_| \_\_____|_|__|_|\___/_|_| |_____|_|_|\_\/_/   \_\_|   |_____| 
           |_   _|  _ \|_ _|  / \  / ___| ____|                   
             | | | |_) || |  / _ \| |  _|  _|                     
             | | |  _ < | | / ___ \ |_| | |___                    
             |_| |_| \_\___/_/   \_\____|_____|      

" 
Write-Host $Banner -ForegroundColor Yellow

                                                                



#Defining important functions
Function Enable-WinRM {
    $SessionArgs = @{
      ComputerName  = $target
      Credential    = $Cred
      SessionOption = New-CimSessionOption -Protocol Dcom
  }
  $MethodArgs = @{
      ClassName     = 'Win32_Process'
      MethodName    = 'Create'
      CimSession    = New-CimSession @SessionArgs
      Arguments     = @{
          CommandLine = "powershell Start-Process powershell -ArgumentList 'Enable-PSRemoting -Force'"
      }
  }
  Invoke-CimMethod @MethodArgs
}

Function Disable-WinRM {
    $SessionArgs = @{
      ComputerName  = $target
      Credential    = $Cred
      SessionOption = New-CimSessionOption -Protocol Dcom
  }
  $MethodArgs = @{
      ClassName     = 'Win32_Process'
      MethodName    = 'Create'
      CimSession    = New-CimSession @SessionArgs
      Arguments     = @{
          CommandLine = "powershell Start-Process powershell -ArgumentList 'Disable-PSRemoting -Force'"
      }
  }
  Invoke-CimMethod @MethodArgs
}

if ($help) {

  Write-Output "
  This tool collect forensic evidence from remote machine and archive it at remote forensic server.
  Arguments:
  -help: Display help and command refecences
  -target: machine to acquire
  -fileshare: Where do you want to save your evidence. Your Default is: [$fileshare]
  -collect: The evidence collection level 
    basic: Just eventlogs
    basic+: basic + memdump
    medium: kape triage !SansTriage Module. (Reference:https://github.com/EricZimmerman/KapeFiles/blob/master/Targets/Compound/!SANS_Triage.tkape)
    medium+: medium + memdump
    full: kape triage with all target modules
    full+: full + memdump
    memdump: memmory dump with kape+winpmem: (Reference: https://github.com/EricZimmerman/KapeFiles/blob/master/Modules/LiveResponse/WinPmem.mkape )
    
  EXAMPLES:

  Full collection + memdump:
  RemoteKapeTriage.exe -colect full+ -target computer1
  
  Basic Collection:
  RemoteKapeTriage.exe -collect basic -target computer1
  "
  
  exit
}
  

If ((-not ($target)) -or (-not ($Collect)) ){
  Write-Host "'-Target' and '-collect' arguments are mandatory. For references, use -help argument." -ForegroundColor Red
  exit
}
if ($collect -notin 'full','full+','medium','medium+','basic','basic+','memdump') {
  Write-Host "'-collect' is mandatory with mandatory values. For references, use -help argument." -ForegroundColor Red
  exit
}



Write-Host "Please, provide PC-Admin account credentials" -ForegroundColor Yellow
$cred = Get-Credential


If (Test-Connection -ComputerName $target -Count 2 -ErrorAction SilentlyContinue) {
  Write-Host "Enabling WinRM on Remote Device using WMI" -ForegroundColor Yellow
  Enable-WinRM | Out-Null 

  Write-Host "Creating WinRM Session for Remote Administration" -ForegroundColor Yellow
  $WinRMSession = New-PSSession -Computername $target -Authentication Kerberos -Credential $cred

  Write-Host "Invoking powershell triage scripts on remote machine through WinRM Session" -ForegroundColor Yellow

  function get-kape-environment {

    function get-kape {
      #$outputname = $env:COMPUTERNAME 
      Write-Host "Creating work folders" -ForegroundColor Yellow
      New-Item -Path c:\kape -ItemType Directory -Force | Out-Null
      New-Item -Path c:\kape\output -ItemType Directory -Force | Out-Null
      New-Item -Path c:\kape\memdump -ItemType Directory -Force | Out-Null
    
      Write-Host "Getting kape from [$using:fileshare]" -ForegroundColor Yellow
      Copy-Item "z:\kape.zip" -Destination "c:\kape\"
    
      Write-Host "Unziping kape tool" -ForegroundColor Yellow
      Set-Location c:\kape
      Expand-Archive c:\kape\kape.zip > $null 2>&1 #<-- This generates the $kapelocalpath
    }
    
    function check-kape {
      Write-Host "Checking if kape already exist on remote machine" -ForegroundColor Yellow
      If (-not (Test-Path -Path $using:kapelocalpath\$using:kapelocalfile -PathType Leaf)) {
            Write-Host "Kape does not exist on remote machine" -ForegroundColor Yellow -BackgroundColor DarkBlue    
            Write-Host "Creating Work Directories and Getting KAPE from [$using:fileshare]" -ForegroundColor Yellow
            get-kape
        }
      else {
          Write-Host "KAPE alredy exist on the remote machine" -ForegroundColor Yellow -BackgroundColor DarkBlue  
      }
    }

    Write-Host "creating [$using:fileshare] as attached drive" -ForegroundColor Yellow
    New-PSDrive -Name z -PSProvider FileSystem -Root $using:fileshare -Credential $using:cred

    check-kape
    Exit-PSSession
    
    
  }



    
  Switch ($Collect) {
    "full" {        
      Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
      Invoke-Command -Session $WinRMSession -ScriptBlock {
        $outputname = $env:COMPUTERNAME    
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
        $CollectCommand = "--tsource C: --tdest c:\kape\output\ --tflush --target !BasicCollection,!SANS_Triage,Avast,AviraAVLogs,Bitdefender,ComboFix,ESET,FSecure,HitmanPro,Malwarebytes, McAfee,McAfee_ePO,RogueKiller,SentinelOne,Sophos,SUPERAntiSpyware,Symantec_AV_Logs,TrendMicro,VIPRE, Webroot,WindowsDefender,Ammyy,AsperaConnect,BoxDrive,CiscoJabber,CloudStorage,ConfluenceLogs,Discord, Dropbox, Exchange,ExchangeClientAccess,ExchangeTransport,FileZilla,GoogleDrive,iTunesBackup,JavaWebCache,Kaseya,LogMeIn,Notepad++, OneDrive,OutlookPSTOST,ScreenConnect,Skype,TeamViewerLogs,TeraCopy,VNCLogs, Chrome,ChromeExtensions,Edge,Firefox,InternetExplorer,WebBrowsers,ApacheAccessLog,IISLogFiles,ManageEngineLogs, MSSQLErrorLog,NGINXLogs,PowerShellConsole,KapeTriage,MiniTimelineCollection,RemoteAdmin, VirtualDisks, Gigatribe,TorrentClients,Torrents,$Boot,$J,$LogFile,$MFT,$SDS,$T,Amcache,ApplicationEvents,BCD,CombinedLogs, EncapsulationLogging,EventLogs,EventLogs-RDP,EventTraceLogs, EvidenceOfExecution,FileSystem,GroupPolicy,LinuxOnWindowsProfileFiles,LnkFilesAndJumpLists,LogFiles,MemoryFiles, MOF,OfficeAutosave,OfficeDocumentCache,Prefetch,RDPCache,RDPLogs,RecentFileCache,Recycle, RecycleBin, RecycleBinContent,RecycleBinMetadata,RegistryHives,RegistryHivesSystem,RegistryHivesUser,ScheduledTasks,SDB, SignatureCatalog,SRUM,StartupInfo,Syscache,ThumbCache,USBDevicesLogs,WBEM,WER,WindowsFirewall,  WindowsIndexSearch,WindowsNotifcationsDB,WindowsTimeline,XPRestorePoints --vss --zip $outputname"
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Copy-Item c:\kape\output\* -Destination z:\
      }
    }
    "full+" {        
      Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
      Invoke-Command -Session $WinRMSession -ScriptBlock {
        $outputname = $env:COMPUTERNAME    
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
        #$CollectCommand = "--tsource C: --tdest c:\kape\output\ --tflush --target !BasicCollection,!SANS_Triage,Avast,AviraAVLogs,Bitdefender,ComboFix,ESET,FSecure,HitmanPro,Malwarebytes, McAfee,McAfee_ePO,RogueKiller,SentinelOne,Sophos,SUPERAntiSpyware,Symantec_AV_Logs,TrendMicro,VIPRE, Webroot,WindowsDefender,Ammyy,AsperaConnect,BoxDrive,CiscoJabber,CloudStorage,ConfluenceLogs,Discord, Dropbox, Exchange,ExchangeClientAccess,ExchangeTransport,FileZilla,GoogleDrive,iTunesBackup,JavaWebCache,Kaseya,LogMeIn,Notepad++, OneDrive,OutlookPSTOST,ScreenConnect,Skype,TeamViewerLogs,TeraCopy,VNCLogs, Chrome,ChromeExtensions,Edge,Firefox,InternetExplorer,WebBrowsers,ApacheAccessLog,IISLogFiles,ManageEngineLogs, MSSQLErrorLog,NGINXLogs,PowerShellConsole,KapeTriage,MiniTimelineCollection,RemoteAdmin, VirtualDisks, Gigatribe,TorrentClients,Torrents,$Boot,$J,$LogFile,$MFT,$SDS,$T,Amcache,ApplicationEvents,BCD,CombinedLogs, EncapsulationLogging,EventLogs,EventLogs-RDP,EventTraceLogs, EvidenceOfExecution,FileSystem,GroupPolicy,LinuxOnWindowsProfileFiles,LnkFilesAndJumpLists,LogFiles,MemoryFiles, MOF,OfficeAutosave,OfficeDocumentCache,Prefetch,RDPCache,RDPLogs,RecentFileCache,Recycle, RecycleBin, RecycleBinContent,RecycleBinMetadata,RegistryHives,RegistryHivesSystem,RegistryHivesUser,ScheduledTasks,SDB, SignatureCatalog,SRUM,StartupInfo,Syscache,ThumbCache,USBDevicesLogs,WBEM,WER,WindowsFirewall,  WindowsIndexSearch,WindowsNotifcationsDB,WindowsTimeline,XPRestorePoints --vss --zip $outputname --mdest C:\kape\memdump\%d%m --mflush --zm true --module WinPmem"
        $CollectCommand = "--tsource C --tdest c:\kape\output\ --target !BasicCollection,!SANS_Triage,Avast,AviraAVLogs,Bitdefender,ComboFix,ESET,FSecure,HitmanPro,Malwarebytes, McAfee,McAfee_ePO,RogueKiller,SentinelOne,Sophos,SUPERAntiSpyware,Symantec_AV_Logs,TrendMicro,VIPRE, Webroot,WindowsDefender,Ammyy,AsperaConnect,BoxDrive,CiscoJabber,CloudStorage,ConfluenceLogs,Discord, Dropbox, Exchange,ExchangeClientAccess,ExchangeTransport,FileZilla,GoogleDrive,iTunesBackup,JavaWebCache,Kaseya,LogMeIn,Notepad++, OneDrive,OutlookPSTOST,ScreenConnect,Skype,TeamViewerLogs,TeraCopy,VNCLogs, Chrome,ChromeExtensions,Edge,Firefox,InternetExplorer,WebBrowsers,ApacheAccessLog,IISLogFiles,ManageEngineLogs, MSSQLErrorLog,NGINXLogs,PowerShellConsole,KapeTriage,MiniTimelineCollection,RemoteAdmin, VirtualDisks, Gigatribe,TorrentClients,Torrents,$Boot,$J,$LogFile,$MFT,$SDS,$T,Amcache,ApplicationEvents,BCD,CombinedLogs, EncapsulationLogging,EventLogs,EventLogs-RDP,EventTraceLogs, EvidenceOfExecution,FileSystem,GroupPolicy,LinuxOnWindowsProfileFiles,LnkFilesAndJumpLists,LogFiles,MemoryFiles, MOF,OfficeAutosave,OfficeDocumentCache,Prefetch,RDPCache,RDPLogs,RecentFileCache,Recycle, RecycleBin, RecycleBinContent,RecycleBinMetadata,RegistryHives,RegistryHivesSystem,RegistryHivesUser,ScheduledTasks,SDB, SignatureCatalog,SRUM,StartupInfo,Syscache,ThumbCache,USBDevicesLogs,WBEM,WER,WindowsFirewall,  WindowsIndexSearch,WindowsNotifcationsDB,WindowsTimeline,XPRestorePoints --vss --tflush --zip $outputname --mdest C:\kape\memdump\ --module WinPmem  --mflush   --zm true"
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Set-Location C:\kape\memdump
        Get-ChildItem *_ModulesOutput.zip | Rename-Item -NewName {$_.Name -replace '_ModulesOutput.zip',"_$env:COMPUTERNAME-memdump.zip"} 
        Copy-Item c:\kape\output\* -Destination z:\
        Copy-Item c:\kape\memdump\* -Destination z:\
      }
    }
    "medium" {
        Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
        Invoke-Command -Session $WinRMSession -ScriptBlock {
        $outputname = $env:COMPUTERNAME    
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
        $CollectCommand = "--tsource C: --tdest c:\kape\output\ --tflush --target !SANS_Triage --zip $outputname"
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Copy-Item c:\kape\output\* -Destination z:\
      }
    }
    "medium+" {
        Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
        Invoke-Command -Session $WinRMSession -ScriptBlock {
        $outputname = $env:COMPUTERNAME    
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow        
        $CollectCommand = "--tsource C --tdest c:\kape\output\ --target !SANS_Triage --tflush --zip $outputname --mdest C:\kape\memdump\ --module WinPmem  --mflush   --zm true"  
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Set-Location C:\kape\memdump
        Get-ChildItem *_ModulesOutput.zip | Rename-Item -NewName {$_.Name -replace '_ModulesOutput.zip',"_$env:COMPUTERNAME-memdump.zip"} 
        Copy-Item c:\kape\output\* -Destination z:\
        Copy-Item c:\kape\memdump\* -Destination z:\
      }
    }

    "basic" {
        Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
        Invoke-Command -Session $WinRMSession -ScriptBlock { 
        $outputname = $env:COMPUTERNAME 
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
        $CollectCommand = "--tsource C: --tdest c:\kape\output\ --tflush --target EventLogs --zip $outputname"
        #$CollectCommand = "--tsource C: --tdest c:\kape\output\ --tflush --target KapeTriage --zip $outputname"
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Copy-Item c:\kape\output\* -Destination z:\
      }
    }
    "basic+" {
        Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
        Invoke-Command -Session $WinRMSession -ScriptBlock { 
        $outputname = $env:COMPUTERNAME 
        Set-Location $using:kapelocalpath
        Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
        $CollectCommand = "--tsource C --tdest c:\kape\output\ --target EventLogs --tflush --zip $outputname --mdest C:\kape\memdump\ --module WinPmem  --mflush   --zm true"           
        Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
        Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
        Set-Location C:\kape\memdump
        Get-ChildItem *_ModulesOutput.zip | Rename-Item -NewName {$_.Name -replace '_ModulesOutput.zip',"_$env:COMPUTERNAME-memdump.zip"}
        Copy-Item c:\kape\output\* -Destination z:\
        Copy-Item c:\kape\memdump\* -Destination z:\
      }
    }
    "memdump" {
      Invoke-Command -Session $WinRMSession -ScriptBlock ${function:get-kape-environment}
      Invoke-Command -Session $WinRMSession -ScriptBlock {      
      Set-Location $using:kapelocalpath
      Write-Host "Running Kape Triage in mode [$using:Collect]" -ForegroundColor Yellow
      $CollectCommand = "--msource C: --mdest C:\kape\memdump\ --module WinPmem  --mflush   --zm true"           
      Start-Process -FilePath $using:kapelocalpath\$using:kapelocalfile -ArgumentList $CollectCommand -Wait
      Write-Host "Saving your evidence at [$using:fileshare]" -ForegroundColor Yellow
      Set-Location C:\kape\memdump
      Get-ChildItem *_ModulesOutput.zip | Rename-Item -NewName {$_.Name -replace '_ModulesOutput.zip',"_$env:COMPUTERNAME-memdump.zip"}   
      Copy-Item c:\kape\memdump\* -Destination z:\
      }
    }
  }

<#   if ($memdump -eq $true) {
    
    Invoke-Command -Session $WinRMSession -ScriptBlock{
      $outputname = $env:COMPUTERNAME 
      Write-Host "creating [$using:fileshare] as attached drive" -ForegroundColor Yellow
      New-PSDrive -Name z -PSProvider FileSystem -Root $using:fileshare -Credential $using:cred
      New-Item c:\kape\memdump -ItemType Directory -ea 0
      Copy-Item "z:\7z.zip" -Destination "c:\kape\memdump"
      Copy-Item "z:\winpmem.exe" -Destination "c:\kape\memdump"
      Set-Location c:\kape\memdump
      Expand-Archive c:\kape\memdump\7z.zip > $null 2>&1 
      Write-Host "Starting memory dump on remote machine" -ForegroundColor Yellow        
      .\winpmem.exe $outputname-memdump.raw
      Set-Location c:\kape\memdump\7z
      .\7za.exe a -tzip ..\$outputname-memdup.zip ..\$outputname-memdump.raw -sdel
      Write-Host "Saving memory dump at [$using:fileshare]"
      Copy-Item ..\$outputname-memdump.zip -Destination z:\
    }      
  } #>


  Write-Host "Removing WinRM Session" -ForegroundColor Yellow
  Remove-PSSession $target

  Write-Host "Disabling WinRM on target machine"  -ForegroundColor Yellow
  Disable-WinRM | Out-Null

  Write-Host "TRIAGE COMPLETED, YOUR EVIDENCE SHOULD BE AT [$fileshare] AS <DATETIME>_<COMPUTERNAME>.zip" -ForegroundColor Yellow
  Write-Host "Happy Hunting ;)" -ForegroundColor Yellow
  Read-Host -Prompt "Press any key to continue..."

} Else {
  Write-Host "$target is offline or can't be reached!" -ForegroundColor Red -BackgroundColor DarkBlue
}
