if ($null -eq $Global:FileCacheHT)    {$Global:FileCacheHT = @{}}
if ($null -eq $Global:FileCacheTable) {[System.Collections.ArrayList]$Global:FileCacheTable = @()}

Function Remove-WebHostCacheTableRecord {
    param (
        [string]$TableName,
        $Key,
        [string]$Scope = 'Global'
    )
    try {$HashTable = Get-Variable -Scope $Scope -Name "$($TableName)HT"} catch {return}
    $HashTableObject = $HashTable.Value
    $Index = $HashTableObject[$Key]
    if ($Null -eq $Index) {return}
    $Table = Get-Variable -Scope $Scope -Name "$($TableName)Table"
    $TableObject = $Table.Value
    $TableObject.remove($Index)
    $HashTableObject.remove($Key)
}
Function Get-WebHostCacheTableRecord {
    param (
        [string]$TableName,
        $Key,
        [string]$Scope = 'Global',
        [switch]$ShowExpired,
        [switch]$PurgeExpired,
        [int]$Last = 1
    )
    $Date = get-date
    try {$HashTable = Get-Variable -Scope $Scope -Name "$($TableName)HT"} catch {return}
    $HashTableObject = $HashTable.Value
    # Set up @Params so that if the -Last parameter is set to 0, all objects will be returned.
    $Params = @{}
    if ($Last -eq 0) {$Params.add('Last',$Last)}
    $Index = $HashTableObject[$Key] | Select-Object @Params
    if ($Null -eq $Index) {return}
    $Table = Get-Variable -Scope $Scope -Name "$($TableName)Table"
    $TableObject = $Table.Value
    $Value = $TableObject[$Index]
    [bool]$isExpired = ($null -ne $Value.TableRecordExpires) -and ($Value.TableRecordExpires -lt $Date)
    if ($Null -eq $Value) {
        return
    }
    elseif ($isExpired) {
        if ($PurgeExpired) {
            $HashTableObject.remove($Key)
            $TableObject.remove($index)
            $Value = $Value | Select-Object @{N='TableRecordEvent';E={'Purged'}},@{N='TableRecordDate';E={$Date}},* -ErrorAction SilentlyContinue
        }
        ELSE {
            $Value = $Value | Select-Object @{N='TableRecordEvent';E={'Expired'}},@{N='TableRecordDate';E={$Date}},* -ErrorAction SilentlyContinue
        }
        if ($ShowExpired) {
            return $Value
        }
        ELSE {
            return
        }
    }
    if (-not $isExpired) {return $Value}
}

Function Set-WebHostCacheTableRecord {
    param (
        [string]$TableName,
        $Key,
        $Value,
        [string]$Scope = 'Global',
        [int]$TimeToLive = 0,
        $Expires,
        [switch]$Append,
        [switch]$Passthrough
    )
    $Date = Get-Date
    if ($TimeToLive -eq 0) {
        $Expires = $null
    }
    else  {
        $Expires = $date.AddSeconds($TimeToLive)
    }
    if (($Expires -gt $date) -and ($TimeToLive -eq 0)) {
        $TimeToLive = ($Expires - $date).seconds
    }
    $Value = $Value | Select-Object -ExcludeProperty TableRecordExpires,TableRecordTimeToLive -ErrorAction SilentlyContinue *,
    @{N='TableRecordTimeToLive';E={$TimeToLive}},
    @{N='TableRecordExpires';E={$Expires}}

    $HashTable = Get-Variable -Scope $Scope -Name "$($TableName)HT" -ErrorAction SilentlyContinue
    if ($Null -eq $HashTable) {
        New-Variable -Scope $Scope -Name "$($TableName)HT" -Value @{}
        $HashTable = Get-Variable -Scope $Scope -Name "$($TableName)HT" -ErrorAction SilentlyContinue
    }
    $HashTableObject = $HashTable.Value
    $Table = Get-Variable -Scope $Scope -Name "$($TableName)Table"
    if ($null -eq $Table) {
        $temp = new-object system.Collections.ArrayList
        $temp.add($null)>$null
        New-Variable -Scope $Scope -Name "$($TableName)Table" -Value $temp.Clone()
        $Table = Get-Variable -Scope $Scope -Name "$($TableName)Table"
        Remove-Variable -Name temp
    }
    $TableObject = $Table.Value 
    $Index = $HashTableObject[$Key]
    if ($null -eq $TableObject) {
            $TableObject = new-object system.Collections.ArrayList
    }
    if ($null -eq $Index) {
        try {
            $HashTableObject.add($Key,$TableObject.Add($Value))
        }
        catch {
            $_ 
        }
    }
    elseif (($null -eq $TableObject[$Index]) -or $Append) {
        $HashTableObject[$Key] = ([array]$HashTableObject[$Key]) + $TableObject.Add($Value)
    }
    ELSE {
        try {$HashTableObject[$HashTableObject[$Key]] = $Value}
        catch {
            $_
        }
    }
    if ($Passthrough) {return $Value} ELSE {return}
}

Function Remove-WebHostCacheFileItem {
    param(
        [string[]]$Path
    )
    $Path | Where-Object {$null -eq $_} | ForEach-Object {Remove-WebHostCacheTableRecord -TableName FileCache -Key $_}
}

Function Get-WebHostCacheFileItem {
    param (
        [string[]]$Path,
        [int]$TimeToLive = 0,
        $Expires,
        [switch]$CacheContent,
        [switch]$WatchChanges
    )
    $Date = get-date
    $Path | Where-Object {$null -ne $_} | 
    ForEach-Object {
        [string]$PathItem = $_
        try {$FileItemError=$null;[bool]$TestPath = test-path -LiteralPath $PathItem} catch {$TestPath = $false; $FileItemError = $_}
        if (test-path -LiteralPath $PathItem) {
            try {$FileItemError=$null;$Item = get-item -LiteralPath $PathItem | Select-Object -ExcludeProperty Directory} catch {$TestPath = $false; $FileItemError = $_}
            $FileItem = $Item | Select-Object -ErrorAction SilentlyContinue @{Name='Content';Expression={$null}},
                @{n='Event';e={[string]'Read File Metadata'}},
                @{n='EventDate';e={$Date}},
                @{N='Error';E={$FileItemError}},
                *
        }
        ELSE {
            return ([pscustomobject]@{
                Event = 'File Not Found'
                Error = $FileItemError
                Fullname = $PathItem
                Name = (split-path -Leaf $PathItem)
                EventDate = $Date
            })
        }

        $CacheItems = Get-WebHostCacheTableRecord -TableName FileCache -Key $PathItem -PurgeExpired -Last ([int][bool](-not $WatchChanges))
        $CacheItem = $CacheItems | Select-Object -Last 1
        [bool]$FilePresent = $null -ne $FileItem
        [bool]$UpdateTTL     = (0 -ne $TimeToLive ) -and ($TimeToLive -ne $CacheItem.TableRecordTimeToLive)
        [bool]$UpdateExpires = ($null -ne $Expires) -and ($Expires -ne $CacheItem.TableRecordExpires)
        [bool]$isCached = $null -ne $CacheItem
        if (($null -ne $FileItem) -and ($null -ne $CacheItem)) {
            [bool]$isCurrent = ($FileItem.LastWriteTime -eq $Cacheitem.LastWriteTime) -and 
            ($FileItem.Length -eq $Cacheitem.Length)
        }
        ELSE {
            $isCurrent=$false
        }

        if ((-not $isCurrent) -and $CacheContent) {
            $FileItem.Content = get-content -LiteralPath $PathItem
            $FileItem.Event = 'Read File Content'
        }
        if ($isCurrent) {
            $CacheItem.Event = 'Read Cache'
            $CacheItem.EventDate = $Date
            $Data = $CacheItem
        } 
        ELSE {$Data = $FileItem}
        $Paramset_SetTableRecord = @{
            Table='FileCache'
            Key=$PathItem
            Value=$Data
            TimeToLive=$TimeToLive
            Passthrough=$True
        }
        if ($null -ne $Expires   ) {$Paramset_SetTableRecord.add('Expires',$Expires)}
        if ($UpdateTTL -or $UpdateExpires -or (-not $isCurrent)) {
            $Data=Set-WebHostCacheTableRecord @Paramset_SetTableRecord
        }
        return $Data
    }
}

Function Find-WebHostCacheFileItem {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$Match
    )
    $Global:FileCacheHT.Keys | Where-Object {$_ -Match $Match} | ForEach-Object {$FileCacheTable[$Global:FileCacheHT[$_]]}
}


Function Find-WebHostCacheTableRecord {
    [CmdletBinding()]
    param (
        [string]$TableName,
        [Parameter()]
        [String]$Match,
        [string]$Scope='Global'
    )
     try {$HashTable = Get-Variable -Scope $Scope -Name "$($TableName)HT"} catch {return}
    $HashTableObject = $HashTable.Value
    $Table = Get-Variable -Scope $Scope -Name "$($TableName)Table"
    $TableObject = $Table.Value

    $HashTableObject.Keys | Where-Object {$_ -Match $Match} | ForEach-Object {$TableObject[$HashTableObject[$_]]}
}

Function Get-WebHostCacheFolderItem {
    param(
        [string]$Path,
        [switch]$Create
    )
    if ($Null -eq $Global:WebHostCacheFolder) {$Global:WebHostCacheFolder=@{}}
    if ($null -eq $Global:WebHostCacheFolder[$Path]) {
        if (Test-Path $Path) {$Global:WebHostCacheFolder.add($Path,(get-item $Path))}
        elseif ($Create) {
            $Global:WebHostCacheFolder.add($Path,(mkdir $Path))
        }
        
    }
    ELSE {
        $Global:WebHostCacheFolder[$Path]
    }
    $Global:WebHostCacheFolder[$Path]
}