# RemoteKapeTriage
A powershell tool that the remote forensic triage adquisitions from Remote windows machines, using [KAPE](https://www.kroll.com/en/insights/publications/cyber/kroll-artifact-parser-extractor-kape) tool.


# Usage Help
Arguments
* -help: Display help and command refecences
* -target: machine to acquire
* -fileshare: Where do you want to save your evidence. Your Default is: [$fileshare]
* -collect: The evidence collection level  
basic: Just eventlogs. 
basic+: basic + memdump. 
medium: kape triage !SansTriage Module (Reference:https://github.com/EricZimmerman/KapeFiles/blob/master/Targets/Compound/!SANS_Triage.tkape)
medium+: medium + memdump. 
⋅⋅⋅full: kape triage with all target modules. 
⋅⋅⋅full+: full + memdump. 
⋅⋅⋅memdump: memmory dump with kape+winpmem: (Reference: https://github.com/EricZimmerman/KapeFiles/blob/master/Modules/LiveResponse/WinPmem.mkape )

# Usage Examples:

* Full collection + memdump:
RemoteKapeTriage.ps1 -target computer1 -colect full+ 

* Basic Collection:

RemoteKapeTriage.ps1 -target computer1 -collect basic 

* Basic Collection + save directory specification:
Remotekapetriage.ps1 -target computer1 -collect basic -fileshare \\\Remoteserver\c$\ 
