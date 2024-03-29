Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}

$Win32_ComputerSystemSelect = @"
AdminPasswordStatus
AutomaticManagedPagefile
AutomaticResetBootOption
AutomaticResetCapability
BootOptionOnLimit
BootOptionOnWatchDog
BootROMSupported
BootupState
Caption
ChassisBootupState
CreationClassName
CurrentTimeZone
DaylightInEffect
Description
DNSHostName
Domain
DomainRole
EnableDaylightSavingsTime
FrontPanelResetStatus
InfraredSupported
InitialLoadInfo
InstallDate
KeyboardPasswordStatus
LastLoadInfo
Manufacturer
Model
Name
NameFormat
NetworkServerModeEnabled
NumberOfLogicalProcessors
NumberOfProcessors
OEMStringArray
PartOfDomain
PauseAfterReset
PCSystemType
PowerManagementCapabilities
PowerManagementSupported
PowerOnPasswordStatus
PowerState
PowerSupplyState
PrimaryOwnerContact
PrimaryOwnerName
ResetCapability
ResetCount
ResetLimit
Roles
Status
SupportContactDescription
SystemStartupDelay
SystemStartupOptions
SystemStartupSetting
SystemType
ThermalState
TotalPhysicalMemory
UserName
WakeUpType
Workgroup
"@ -split "`n" -replace "\s"

'<hr>'
Convertto-DOMtable -  $Myinvocation.mycommand 


'<hr>'
html -tagname h2 -innerhtml "Drive Space"
Get-WmiObject win32_volume | Where-Object{$_.Capacity} | Select-Object DriveLetter,DriveType,FileSystem,Capacity,FreeSpace  | Write_HTable

