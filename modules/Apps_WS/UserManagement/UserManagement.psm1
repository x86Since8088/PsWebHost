$Files = Get-ChildItem "$(split-path ($MyInvocation.MyCommand.Definition,$MyInvocation.MyCommand.Module.Path|?{$_ -match '^(\\\\|\w:)'}|?{try{test-path $_}catch{}}))\UserManagement" *.ps1
Import-Module "$Global:Project_Modules\Data_File_WS\PSWEB_FileCache\PSWEB_FileCache.psm1"
$UpdatedFunctionFiles = (
    Get-WebHostCacheFileItem $Files.fullname -Expires (get-date).AddSeconds(3) | Where-Object {$_.event -eq 'Read File'}
).fullname

$UpdatedFunctionFiles | Where-Object {$_.fullname} | ForEach-Object {
    write-verbose -Message "Reloading File $_" -Verbose
    . ([string]$_.fullname) 
}