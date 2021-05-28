# RemoteKapeTriage
A powershell tool that automate the remote forensic evidence adquisitions (triage) from Remote windows machines, using [KAPE](https://www.kroll.com/en/insights/publications/cyber/kroll-artifact-parser-extractor-kape) tool.

Due deficiences in KAPE built in remote adquisitions capabilities while adquiring registry keys and other elements through UNC Path, i decided to automate the process of running kape on remote computers, but running the tools locally in the target and archiving the evidence in remote server.


**Usage Help**

**Arguments**
* **-help:** Display help and command refecences
* **-target:** machine to acquire
* **-fileshare:** Where do you want to save your evidence. Your Default is: [$fileshare]
* **-collect:** The evidence collection level
basic: Just eventlogs. 
basic+: basic + memdump. 
medium: kape triage !SansTriage Module. 
medium+: medium + memdump. 
full: kape triage with all target modules. 
full+: full + memdump. 
memdump: memmory dump with kape+winpmem. 

**Usage Examples:**

**Full collection + memdump:**
RemoteKapeTriage.ps1 -target computer1 -colect full+ 

**Basic Collection:**

RemoteKapeTriage.ps1 -target computer1 -collect basic 

**Basic Collection + save directory specification:**
Remotekapetriage.ps1 -target computer1 -collect basic -fileshare \\\Remoteserver\c$\ 
