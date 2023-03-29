function AddhttpListener {
    Param (
        $Authentication = 'anonymous',
        $ListenerIdentification = $Authentication,
        $Prefix,
        $ListenerObject,
        [uint32]$Timout_MinSendBytesPerSecond=10kb
    )
    if ($null -eq $Global:ListenerTable) {$Global:ListenerTable=@{}}
    if ($null -eq $Global:ListenerArray) {$Global:ListenerArray=new-object System.Collections.arraylist}
    Import-Module -Name "$Global:Project_Modules\HTTPListener_WS\WebHost_Listener\WebHost_Listener.psm1" -DisableNameChecking
    $ListenerObject = Get-WebHostListener $ListenerIdentification
    if ($Null -eq $ListenerObject) {
        $ListenerObject = New-Object System.Net.HttpListener
    }
    else {
        Write-Verbose "Adding $prefix to existing Listeners identified as '$ListenerIdentification'."
    }
    $ListenerObject.AuthenticationSchemes = $Authentication
    $ListenerObject.TimeoutManager.DrainEntityBody = [timespan]::FromSeconds(10)
    $ListenerObject.TimeoutManager.IdleConnection = [timespan]::FromSeconds(10)
    $ListenerObject.TimeoutManager.RequestQueue = [timespan]::FromSeconds(10)
    $ListenerObject.TimeoutManager.MinSendBytesPerSecond = $Timout_MinSendBytesPerSecond
    $ListenerObject.TimeoutManager.EntityBody = [timespan]::FromSeconds(10)
    $Prefix|Where-Object {$_}|Foreach-Object {
        $ListenerObject.Prefixes.Add($_)
    }
    $Lookup = $global:ListenerTable[$ListenerIdentification]
    if ($Null -NE $Lookup) {
        if ($Null -eq $global:ListenerArray[$Lookup]) {
            $global:ListenerTable[$Lookup] = $global:ListenerArray.add($ListenerObject)
        }
    }
    ELSE
    {
        $global:ListenerTable.add($Authentication,$global:ListenerArray.add($ListenerObject))
    }
}

Function Start-WebHostListener {
    Get-WebHostListener | Where-Object{$Nul -ne $_.prefixes} | Foreach-Object{
        $Error.clear()
        $Listener = $_
        new-object psobject -property @{
            Date=Get-Date
            Action='Start listener'
            Object=($Listener)
            Output=$Listener.Start()
            Error=$Error
        }
    }
}

Function Get-WebHostListener {
    param (
        [string[]]$ListenerIdentification = $Global:ListenerTable.Keys
    )
    foreach ($ListenerIdentificationItem in $ListenerIdentification) {
        [int]$TableItem=$Global:ListenerTable[$ListenerIdentificationItem]
        if ($null -eq $TableItem) {}
        else {$Global:ListenerArray[$TableItem]}
    }
}

Function Get-WebHostRoutes {
    param (
        [string]$Path,
        [hashtable[]]$RouteHashTableArray
    )
    $RouteHashTableArray | ForEach-Object{ 
        $RouteHashTable
        New-WebhostHttpListenerRoute @RouteHashTable 
    }
}

Function New-WebhostHttpListenerRoute {
    param (
        [ValidateSet(
            'Redirect'
        )]
        [string]$Type,
        [string]$VirtualFolder,
        [string]$RedirectionDestination,
        [string]$mimeType, #= 'text/html',
        [alias('value')][scriptblock]$ScriptBlock={
            param ($SessionObject=$Global:SessionObject)
            $Response=$SessionObject.context.response
            Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 300
            '301 Moved Permanently'
            $response.statusCode=301
            $response.AddHeader("Location",$RedirectionDestination)
        }
    )
    Write-Warning -Message "$($myinvocation.mycommand.Definition) is obsolete! $(Get-WebHostPSCallStackText -First 2 -Skip 1)"
    @{
        Name = $VirtualFolder
        mimeType = $mimeType
        Authentication = $Authentication
        Value = $ScriptBlock
    }
}

Function LoadListenersWithPrefixes {
    param (
        $Routes=$Global:Routes,
        $URLPrefixes=$Global:URLPrefixes,
        $Authentication = 'anonymous'
    )
    foreach ($URLPrefixeItem in $URLPrefixes) {
        if ($URLPrefixeItem -notmatch '\w|^https{0,1}:') {}
        elseif ($_ -match '\+$') {}
        else {
            if (
                ($Global:Project_URLRoot -eq '') -or
                (-not ($Global:Project_URLRoot -is [string]))
            ) {[string]$Global:Project_URLRoot = '/'}
            $NewPrefixString+=$URLPrefixeItem + $Global:Project_URLRoot -replace '(\w)///*','$1/'
            write-host AddhttpListener -Authentication $Authentication -Prefix $NewPrefixString
            AddhttpListener -Authentication $Authentication -Prefix $NewPrefixString
        }
    }
}


Function Listener {
    param (
        [string[]]$url = ('http://localhost/'),
        [string]$Port='982-984',
        [switch]$ListenOnHostname=$false,
        [switch]$StopListener,
        [string]$AuthenticationSchemes = "Anonymous",
        [string]$DefaultServiceNames
    )
    begin {
        Import-Module "$Global:Project_Modules\HTTPListener_WS\Function_Core\Function_Core.psm1" -disableNameChecking
        LastCall #Remove old listeners.
        #[gc]::Collect()
        Add-Type -AssemblyName System.Web | out-null
        [int[]]$Ports=$Port -split '-' |Where-Object{$_}
        $RandomPort = GetRandomUnusedTCPPort -Low $Ports[0] -High $Ports[-1]

        write-verbose -Message "Starting Listener`n$(
            Get-PSCallStack | Where-Object {$_.Location -match '^[a-z\\]'} | ForEach-Object {
                (
                $_ | Format-List | 
                out-string
                )  -split '\n' | Where-Object {$_ -notmatch '^\s*$'} | ForEach-Object{"`n|`t$_"}
                "`n|"
            }
        )" -Verbose
        
        [string[]]$Global:URLPrefixes = @()
        foreach ($URLItem in $url) {
            if (($URLItem -replace '^.*://') -match ':') {
                $Global:URLPrefixes+=$URLItem
            }
            else {
                $Global:URLPrefixes+= $URLItem -replace '^(.*://)(.*?)(/.*)',"`$1`$2:$RandomPort`$3"
            }
        }
        if ($ListenOnHostname)
        {
            [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://localhost:$($RandomPort)/")
            [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://127.0.0.1:$($RandomPort)/")
            [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://$($env:COMPUTERNAME):$($RandomPort)/")
            [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain):$($RandomPort)/")
        }
        $Global:URLPrefixes=$Global:URLPrefixes |Where-Object {-not ($_ -match '\.[a-z]*:/')} | Sort-Object -Unique
        
        . "$Global:Project_Root\Scripts\Router.ps1" 
        . LoadListenersWithPrefixes
        $ErrorActionPreference = "Continue"

        Start-WebHostListener

        $Global:Routes | Format-Table -AutoSize -wrap
        Get-WebHostListener | Select-Object 
        
        Write-Host "Listening on:`n`t$($Global:ListenerArray.prefixes -join "`n`t")..."
        get-job -Name PeriodicRequest* -ea Ignore|
            Where-Object{$_.Name -eq 'PeriodicRequest'}|
            Stop-Job -Name PeriodicRequest -PassThru |
            Remove-Job -Name PeriodicRequest
        Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(5,"http://localhost:$($RandomPort)/blank"))
        
        $AutoFunctionReloadCount = 0
        while (Get-WebHostListener|Where-Object{$_.IsListening})
        {
            ProcessAsynchronousOperationArray -AsynchronousOperationArray $AsynchronousOperationArray
            $AutoFunctionReloadCount++
            if ($AutoFunctionReloadCount -gt 300)
            {
                . LoadFunctions
                $AutoFunctionReloadCount=0
            }
        }
    }

    Process {}
    End {
        LastCall 2> $null
        Stop-Job -Name PeriodicRequest*
        Remove-Job -Name PeriodicRequest*
    }
}
