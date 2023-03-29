param (
    [switch]$LoadEnvironment
)
try {lastcall} catch {}
remove-module *

$ErrorActionPreference = 'continue'
#while ($true) {
    #Reload Modules
    Get-ChildItem $Global:Project_Modules -Recurse *.psm1 | 
        ForEach-Object{Import-Module  $_.FullName -DisableNameChecking}
    Get-ChildItem $Global:Project_Modules *.ps1 | 
        Where-Object{$_.fullname -notmatch 'Disabled'} | 
        ForEach-Object{. $_.FullName}
    $Listener_WebHostFolders = Get-WebHostFolders -InvocationObject $MyInvocation
    $Config = $Listener_WebHostFolders
    if ($LoadEnvironment) {
        Write-Warning -Message "-LoadEnvironment was specified.  Exiting."
    }
    #while ($True) {
        . Listener -Port 8123 #  8000-9000
    #}
#}