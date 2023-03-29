$Global:RouteTable=@{}
$Global:Routes = new-object System.Collections.ArrayList

return (write-warning -Message "Deprecating Router_Config.ps1")
Get-ChildItem "$Global:Project_Root\Routes\Method_*.ps1" -Recurse   | Where-Object {$null -ne $_} |
    Where-Object {$null -ne $_} |    
    ForEach-Object{
        $RouteFile=$_
        $HT = & $RouteFile.FullName
        @{
            Name=($RouteFile.Name.replace("Method_",'') -replace '\.ps1$') + ' ' + (split-path $RouteFile.FullName).Replace("$Global:Project_Root\Routes",'')
            MimeType=$HT.mimeType
            Authentication=$HT.Authentication
            Value=$HT.Values
        }
    } | 
    Where-Object {$_.gettype().Name -eq 'Hashtable'} |
    ForEach-Object {new-object psobject -property $_} | ForEach-Object {
    if (-not ($Global:RouteTable[$_.name]))
    {
        $Global:RouteTable.add($_.name,$Global:Routes.Add($_))
        try{
            #Set-WebHostCacheTableRecord -TableName Routes -Key $_.Name -Value $_ -TimeToLive ([int]$_.TimeToLive)
        }
        catch {
            $_ | write-error
        }
    }
}

    Get-ChildItem "$Global:Project_Root\wwwroot" |
        Where-Object {$_.psiscontainer} | 
        ForEach-Object {
        @{
            Name = 'GET ' + $_.fullname.replace("$Global:Project_Root\wwwroot\","/").replace("\","/");          
            Value = {
                Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 300;
                $Data = get-content ("$Global:Project_Root\wwwroot\" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\' -replace '^GET '))
                return $Data
            };
            
            Authentication = 'Anonymous'
        }
} | Where-Object {$_.name} | ForEach-Object {new-object psobject -property $_} |
    ForEach-Object {
    $Item = $_
    $Item.Name = $Item.Name -replace '^///*','/'
    if (-not ($Global:RouteTable[$_.name]))
    {
        $Global:RouteTable.add($_.name,$Global:Routes.Add($_))
        #Set-WebHostCacheTableRecord -TableName Routes -Key $_.Name -Value $_ -TimeToLive ([int]$_.TimeToLive)
    }
    Else
    {
        Write-Information -MessageData @{
            Message="Route in '$Global:Project_Root\wwwroot\$($_.name))' cannot be added because it conflicts with a previously defined route."
            Path="$Global:Project_Root\wwwroot\$($_.name))"
        } -Tags 'wwwroot','Route',$_.name 
    }
}
