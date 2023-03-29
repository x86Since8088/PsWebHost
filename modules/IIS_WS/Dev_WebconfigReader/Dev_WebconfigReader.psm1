return
Function Get_WebConfig {
    [CmdletBinding()]
    param (
        [Parameter()]
        [TypeName]
        $IISConfigFolder
    )
    $ConfigEntries=New-Object System.Collections.ArrayList
    $ConfigPathsHT=@{}
    function AddConfig{
        param ($ConfigFile,$nodes)
        $ConfigFolderPath=split-path $ConfigFile 
        $LU=$ConfigPathsHT[$ConfigFolderPath]
        if ($LU -eq $null)
        {
        
        }
        ELSE
        {
            $ConfigPathsHT[$ConfigFolderPath]#=
        }
    }
    if ($ConfigFile -eq $null) {$ConfigFile = Get-ChildItem -Recurse $IISConfigFolder web.config}
    $Configfile | %{
        $ConfigfileItem = $_
        [xml]$Webconfig=gc $ConfigFileItem.fullname
        $objs = @()
        $nodes = $Webconfig.SelectNodes("//*[*]") 
        foreach ($node in $nodes) {
            $sid = $node.attributes['SID'].value
            $dispName = $node.attributes['DISPLAYNAME'].value
            $obj = new-object psobject -prop @{SID=$sid;DISPNAME=$dispName}
            $objs += $obj
        }
        $objs
    }
}