param (
    $HTTPSListenerContext,
    [switch]$GetApprovedArgs,
    $AppArguments
)
#if (-not $AppArguments) {$GetApprovedArgs = $True}
if ($GetApprovedArgs) 
{
    return ('Run',(New-Object psobject -Property @{Name='Command';Value='Run'}))
}
if ($AppArguments | ?{($_.Name -eq 'Command') -and ($_.Value -eq 'Run')} )
{
    #. "$script:ScriptFolder\Functions.ps1"
    gci "$ScriptFolder\Functions" *.ps1 | %{. $_.fullname}
}