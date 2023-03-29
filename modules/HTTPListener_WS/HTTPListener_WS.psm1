if ($Null -eq $Script:FileDateHT) {$Script:FileDateHT=[hashtable]}
$Script:Mycommand=$MyInvocation.MyCommand
$Script:WorkingFolder=split-path $script:Mycommand.Source
$Script:Folders = Get-ChildItem -Attributes directory -Path  $Script:WorkingFolder -ErrorAction SilentlyContinue
ForEach ($FolderItem in $Folders) {
    $ModuleFileName=($FolderItem.FullName + '\' + $FolderItem.Name + '.psm1')
    if (Test-path $ModuleFileName) {
        if ($ModuleFile.LastWriteTime -gt $Script:FileDateHT[$FolderItem.Name]) {
            $ModuleFile.fullname
            Remove-Module $ModuleFile.fullname -ErrorAction Ignore            try {
                Import-Module $ModuleFile.fullname -DisableNameChecking
                $Script:FileDateHT[$ModuleFile.Name]=$ModuleFile.LastWriteTime
            }
            catch{}
        }
    }
}
