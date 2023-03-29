Function Get-WebHostFolders {
    param (
        $InvocationObject
    )
    if ($null -eq $InvocationObject) {
        [string]$CallStackText=Get-PSCallStack | Select-Object -first 1 -skip 1 | format-list | out-string
        $MSGText = "Format: Get-WebHostFolders -InvocationObject `$MyInvocation `n $CallStackText"
        write-error $MSGText -Category InvalidArgument
    }

    if (test-path $InvocationObject.MyCommand.Definition) {
        $ScriptPath=$InvocationObject.MyCommand.Definition
        $ScriptFolderReadOnly = split-path $ScriptPath
    }
    elseif (test-path $InvocationObject.MyCommand.Module.Path) {
        $ScriptPath=$InvocationObject.MyCommand.Module.Path + '\' + $InvocationObject.MyCommand.name
        $ScriptFolderReadOnly = (Get-WebHostCacheFolderItem -Path (split-path $ScriptPath) -Create).Fullname
    }
   
    $RootFolder = $Global:Project_Root
    $ScriptFolderName = split-path -Leaf $ScriptFolderReadOnly
    $ScriptName = split-path -Leaf ($ScriptPath -replace '\.psm{0,1}1')
    $DataPath = Get-WebHostCacheFolderItem -Path "$RootFolder\Storage\$ScriptFolderName\$ScriptName" -Create
    

    new-object psobject -Property @{
        ScriptFolderReadOnly=$ScriptFolderReadOnly
        ScriptFolderName=$ScriptFolderName
        ScriptName=$ScriptName
        DataPath=$DataPath
    }
}

