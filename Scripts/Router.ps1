Write-Warning -Message  "Router.ps1 is deprecated."

$UpdatedFunctionFiles = (
    Get-WebHostCacheFileItem (
        Get-ChildItem "$Global:Project_Modules" *.ps1
    ).fullname | Where-Object {$_.event -eq 'Read File'}
).fullname
   
$UpdatedFunctionFiles | Where-Object {$_.fullname} | ForEach-Object {
    write-verbose -Message "Reloading File $_" -Verbose
    . $_
}

. ([string]$myinvocation.MyCommand.Definition -replace '\.ps1','_Config.ps1')

