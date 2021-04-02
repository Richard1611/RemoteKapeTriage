$DebugPreference ="Continue"
Write-Host "
  ______ ____  _____  ______ _   _  _____ _____ _____   _______ _____  _____          _____ ______
|  ____/ __ \|  __ \|  ____| \ | |/ ____|_   _/ ____| |__   __|  __ \|_   _|   /\   / ____|  ____| 
| |__ | |  | | |__) | |__  |  \| | (___   | || |         | |  | |__) | | |    /  \ | |  __| |__    
|  __|| |  | |  _  /|  __| | . `  |\___ \  | || |         | |  |  _  /  | |   / /\ \| | |_ |  __|   
| |   | |__| | | \ \| |____| |\  |____) |_| || |____     | |  | | \ \ _| |_ / ____ \ |__| | |____  
|_|    \____/|_|__\_\______|_|_\_|_____/|_____\_____|____|_|__|_|  \_\_____/_/_   \_\_____|______| 
    /\  | |  | |__   __/ __ \|  \/  |   /\|__   __|  ____|  __ \  |__   __/ __ \ / __ \| |         
   /  \ | |  | |  | | | |  | | \  / |  /  \  | |  | |__  | |  | |    | | | |  | | |  | | |         
  / /\ \| |  | |  | | | |  | | |\/| | / /\ \ | |  |  __| | |  | |    | | | |  | | |  | | |         
 / ____ \ |__| |  | | | |__| | |  | |/ ____ \| |  | |____| |__| |    | | | |__| | |__| | |____     
/_/    \_\____/   |_|  \____/|_|  |_/_/    \_\_|  |______|_____/     |_|  \____/ \____/|______|    
                                                                                                   
By Richard Arias ;)                                                                                                    "

#Defining variables
#$UserCredential = Get-Credential
$targetname = Read-Host Nombre de equipo a capturar

Write-Debug "Enabling WinRM on remote machine"

C:\psexec\PsExec64.exe -nobanner -accepteula \\$targetname -s winrm.cmd quickconfig -q 

#Creating WinRM Session for Remote Administration 
$WinRMSession = New-PSSession -Computername $targetname -Authentication Kerberos 
#-Credential $UserCredential

Write-Debug "Invoking powershell triage scripts on remote machine through WinRM Session"
Write-Debug "Please, provide local administrator credentials for FORENSE01"
Invoke-Command -Session $WinRMSession -ScriptBlock {
#Defining variables

$UserCredential = Get-Credential
$outputname = $env:COMPUTERNAME

Write-Debug "reating forense01\j as attached drive"
New-PSDrive -Name forense01d -PSProvider FileSystem -Root \\forense01\d$ -Credential $UserCredential

Write-Debug "Cleaning up previous working directory"
Remove-Item c:\kape -Recurse -Force -Confirm:$false

Write-Debug "Creating work folders"
New-Item -Path c:\kape -ItemType Directory -Force
New-Item -Path c:\kape\output -ItemType Directory -Force

Write-Debug "Copying kape from Forense01 to work directory"
Copy-Item "\\forense01\j$\kape8.zip" -Destination "c:\kape\"

Write-Debug "Unziping and runnink our kape triage tool"
Set-Location c:\kape
Expand-Archive c:\kape\kape8.zip
Set-Location C:\kape\kape8\kape8
.\kape.exe --tsource C: --tdest c:\kape\output\%d%m --target !BasicCollection,!SANS_Triage,Avast,AviraAVLogs,Bitdefender,ComboFix,ESET,FSecure,HitmanPro,Malwarebytes, McAfee,McAfee_ePO,RogueKiller,SentinelOne,Sophos,SUPERAntiSpyware,Symantec_AV_Logs,TrendMicro,VIPRE, Webroot,WindowsDefender,Ammyy,AsperaConnect,BoxDrive,CiscoJabber,CloudStorage,ConfluenceLogs,Discord, Dropbox, Exchange,ExchangeClientAccess,ExchangeTransport,FileZilla,GoogleDrive,iTunesBackup,JavaWebCache,Kaseya,LogMeIn,Notepad++, OneDrive,OutlookPSTOST,ScreenConnect,Skype,TeamViewerLogs,TeraCopy,VNCLogs, Chrome,ChromeExtensions,Edge,Firefox,InternetExplorer,WebBrowsers,ApacheAccessLog,IISLogFiles,ManageEngineLogs, MSSQLErrorLog,NGINXLogs,PowerShellConsole,KapeTriage,MiniTimelineCollection,RemoteAdmin, VirtualDisks, Gigatribe,TorrentClients,Torrents,$Boot,$J,$LogFile,$MFT,$SDS,$T,Amcache,ApplicationEvents,BCD,CombinedLogs, EncapsulationLogging,EventLogs,EventLogs-RDP,EventTraceLogs, EvidenceOfExecution,FileSystem,GroupPolicy,LinuxOnWindowsProfileFiles,LnkFilesAndJumpLists,LogFiles,MemoryFiles, MOF,OfficeAutosave,OfficeDocumentCache,Prefetch,RDPCache,RDPLogs,RecentFileCache,Recycle, RecycleBin, RecycleBinContent,RecycleBinMetadata,RegistryHives,RegistryHivesSystem,RegistryHivesUser,ScheduledTasks,SDB, SignatureCatalog,SRUM,StartupInfo,Syscache,ThumbCache,USBDevicesLogs,WBEM,WER,WindowsFirewall,  WindowsIndexSearch,WindowsNotifcationsDB,WindowsTimeline,XPRestorePoints --vss

Write-Debug "Zipping output evidence"
Compress-Archive c:\kape\output\* c:\kape\output\$outputname.zip

Write-Debug "Copying our evidence to Forense01 as HOSTNAME.zip"
Copy-Item c:\kape\output\$outputname.zip -Destination "\\forense01\j$\"
Set-Location c:\

Write-Debug "Cleaning up working directory"
Remove-Item c:\kape -Recurse -Force -Confirm:$false

Write-Debug "Exiting winRM Session"
exit
} 

Write-Debug "Removing WinRM Session"
Remove-PSSession $WinRMSession

Write-Debug " TRIAGE COMPLETED, YOUR EVIDENCE SHOULD BE AT \\FORENSE01\J$\ AS COMPUTERNAME.zip"
Write-Debug "Happy Hunting ;)"
pause