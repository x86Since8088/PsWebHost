param (
    [string[]]$url = ('http://+'),
    [string]$Port='982-984',
    [switch]$ListenOnHostname=$false,
    $routes,
    [switch]$StopListener,
    [string]$AuthenticationSchemes = "Anonymous",
    #[string]$AuthenticationSchemes = "Anonymous",
    #[string]$AuthenticationSchemes = "Basic",
    #[string]$AuthenticationSchemes = "IntegratedWindowsAuthentication",
    [string]$DefaultServiceNames,
    [switch]$NoIE=$True,
    [switch]$Install,
    $ServiceAccountName,
    $ServiceAccountPassword
)

begin {
    $script:ScriptPath = $MyInvocation.MyCommand.Definition
    $Global:ScriptPath = $script:ScriptPath
    $script:ScriptFolder = SPLIT-PATH $MyInvocation.MyCommand.Definition
    $global:ScriptFolder = $script:ScriptFolder
    $Script:ScriptName = (split-path -Leaf $script:ScriptPath) -replace '\.ps1$'
    $AppsFolder = "$Script:ScriptFolder\Apps"
    if (-not (test-path $AppsFolder)) {md $AppsFolder}
    $Apps = gci $AppsFolder *.ps1

    $Ports = & ([scriptblock]::create(('(' + ($script:port -replace '-','..') + ')'))) | sort
    Function LoadFunctions {
        gci "$script:ScriptFolder\Functions" *.ps1 | %{. $_.fullname}
    }
    . LoadFunctions
    try {. LastCall} catch {}
    $url = $url | ?{$_}|%{
        if ($_ -and -not ($_ -like '*/')) {
            $_ + '/'
        }
        ELSE
        {
            $_
        }
    }
    $RandomPort = GetRandomUnusedTCPPort -Low $Ports[0] -High $Ports[-1]
    write-host Random Port Selected: $RandomPort
    #if (-not (get-NetFirewallRule -name "Incoming_HTTP_$RandomPort" -ErrorAction SilentlyContinue)) 
    #{
    #    new-NetFirewallRule -name "Incoming_HTTP_$RandomPort" -Enabled 1 -DisplayName "Incoming_HTTP_$RandomPort" -Profile PUBLIC,PRIVATE,domain -Action allow -Protocol TCP -LocalPort $RandomPort -PolicyStore PersistentStore -EdgeTraversalPolicy Allow 
    #}

    [string[]]$Global:URLPrefixes = (
        $url| ?{$_ -match '^[a-z]'}| %{
            if (($url -split ':').count -gt 2) 
            {$_}
            ELSE
            {
                $URLItem=$_
                $_ -replace '^(\w\w*?:\/\/)(.*?)(\/.*?)$',"`$1`$2:$($RandomPort)`$3"
                $routes | ?{$_.name -match '^[a-z]'}  |%{
                    $RouteName = $_.name
                    $URLItem -replace '^(\w\w*?:\/\/)(.*?)(\/.*?)$',"`$1`$2:$($RandomPort)`$3$($RouteName)/"
                }
                $_ -replace '^(\w\w*?:\/\/)(.*?)(\/.*?)$',"`$1`$2:$($RandomPort)`$3+/"
            }
        }
    )
    if ($ListenOnHostname)
    {
        [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://localhost:$($RandomPort)/")
        [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://127.0.0.1:$($RandomPort)/")
        [string[]]$Global:URLPrefixes = $Global:URLPrefixes + ("http://$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain):$($RandomPort)/")
    }
    $Global:URLPrefixes=$Global:URLPrefixes |?{-not ($_ -match '\.[a-z]*:/')} | sort -Unique
    if ($Install)
    {
        $PasswordGen = $ServiceAccountPassword
        $Ports |?{$_}|%{
            $PortNumberItem = $_
            if ($ServiceAccountName -eq $null)
            {
                $ServiceAccountName = (($Script:ScriptName -replace ':' -replace '\\|\/','_' -split '' |?{$_ -match '[a-z0-9]|-|_| |\.'}) -join '') + 
                    '_Port' + 
                    $PortNumberItem
                $PasswordGen=New-RandomPassword -Length 25 -MinUpperCaseLetters 3 -MinLowerCaseLetters 3 -MinCapSpecialChars 3 -MinNumbers 3
                $ADSI = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
                $ServiceAccountObject = $ADSI.Children | where {
                    $_.SchemaClassName -eq 'user' -and 
                    $_.Name -eq $ServiceAccountName 
                }
                if ( $ServiceAccountObject -eq $null)
                {
                    $ServiceAccountObject = $ADSI.Create("User",$ServiceAccountName)
                }
                $ServiceAccountObject.SetPassword($PasswordGen)
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.HomeDirectory = "$script:ScriptFolder\Logs"
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.FullName = "Local User for $script:ScriptPath"
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
                $ServiceAccountObject.SetInfo()

            }
            #Make a secure password that will meet most secureity standards.
            Add-UserToLoginAsBatch -UserID $ServiceAccountName
            $URLACLData = (netsh http show urlacl) -join "`n" -split '\n\n'
            $URLACLData|?{$_ -like "*http://+:$PortNumberItem/*"} | %{$_ -split '\n'|?{$_ -match 'Reserved URL '}} |%{$_ -split ':\s\s*'|select -Last 1} | %{
                write-host netsh http delete urlacl "url=$_"
                netsh http delete urlacl "url=$_"
            }
            if (-not ($URLACLData|?{$_ -like "*http://+:$PortNumberItem/*"} | ?{$_ -like "*User: $ServiceAccountName*"}))
            {
                netsh http add urlacl url=http://+:$PortNumberItem/ user="$ServiceAccountName"
                netsh http add urlacl url=http://+:$PortNumberItem/+ user="$ServiceAccountName"
                [string[]]''
                $Global:URLPrefixes | ?{$_} | %{
                    $PrefixItem = $_
                    $routes |?{$_.name} | %{
                        $RoutName = "/$($_.name)" -replace '\/\/*','/'

                        $TestPrefix = $PrefixItem -replace ':\d\d*\/*',":$PortNumberItem$($RoutName)"
                        netsh http add urlacl ("url=$TestPrefix" -replace '') user="$ServiceAccountName"
                    }
                }
            }
            if ((netsh advfirewall firewall show  rule "name=$ServiceAccountName" ) -match 'No rules match the specified criteria')
            {
                write-host Adding firewall rules
                netsh advfirewall firewall add rule "name=$ServiceAccountName" protocol=TCP dir=in "localport=$PortNumberItem" security=notrequired  action=allow edge=yes profile=any 
            }
            ELSE
            {
                write-host firewall rules exist
            }
            $ScheduledTask=Get-ScheduledTask -TaskName $ServiceAccountName -ErrorAction SilentlyContinue
            $ScheduledTaskAction = New-ScheduledTaskAction -Execute cmd -Argument "/c ""$($script:ScriptPath -replace '\.ps1$','.bat')"" -Port $PortNumberItem' > ""$script:ScriptFolder\Logs\$ServiceAccountName.log""" -WorkingDirectory "$script:ScriptFolder\Logs"
            $ScheduledTaskTrigger.RandomDelay=(New-TimeSpan -Minutes 2 ) 
            $ScheduledTaskTrigger.Repetition = 'Indefinite'
            if ($PasswordGen)
            {
                $ScheduledTaskTrigger = New-ScheduledTaskTrigger -AtStartup
            }
            ELSE
            {
                $ScheduledTaskTrigger = New-ScheduledTaskTrigger -AtLogOn 
            }
            $ScheduledTaskSettingsSet = New-ScheduledTaskSettingsSet
            $ScheduledTaskSettingsSet.AllowDemandStart = $True
            #$ScheduledTaskSettingsSet.MultipleInstances = 'IgnoreNew'
            $SCheduledTaskSplat = @{
                Trigger=$ScheduledTaskTrigger
                Description=$script:ScriptPath
                User=$ServiceAccountName
                Action=$ScheduledTaskAction
                TaskPath='\'
                Settings=$ScheduledTaskSettingsSet
                Force=$True
                RunLevel='Highest'
            }
            if ($PasswordGen) 
            {
                Add-Member -InputObject $SCheduledTaskSplat -MemberType NoteProperty -Name User -Value $ServiceAccountName -Force
                Add-Member -InputObject $SCheduledTaskSplat -MemberType NoteProperty -Name Password -Value $PasswordGen -Force
            }
            ELSE
            {
                Add-Member -InputObject $SCheduledTaskSplat -MemberType NoteProperty -Name Principal -Value $ServiceAccountName -Force
            }
            $ScheduledTask = Register-ScheduledTask -TaskName $ServiceAccountName @SCheduledTaskSplat 
            icacls $script:ScriptFolder /grant "$($ServiceAccountName):(OI)(CI)RX"
            icacls "$script:ScriptFolder\Logs" /grant "$($ServiceAccountName):(OI)(CI)M"
        }
        return
    }
    $Global:responseArray = New-Object System.Collections.ArrayList
    $AsynchronousOperationArray = New-Object System.Collections.ArrayList
    $Global:HTable_Data = new-object system.collections.arraylist

    if (-not $Global:ThemeName) {$Global:ThemeName = 'Blue1'}
    Update_Theme -Name $Global:ThemeName 
    $ErrorActionPreference = "Continue"
    $Global:Win32_ComputerSystem = Get-WmiObject win32_computersystem 

    $F = 'C:\Program Files\Internet Explorer\iexplore.exe'
    if (Test-Path $F) {$IE = $F}
    $F = 'C:\Program Files (x86)\Internet Explorer\iexplore.exe'
    if (Test-Path $F) {$IE = $F}

    try {$global:listener.close()} catch{}
    try {$global:listener.dispose()} catch{}
    $global:listener = New-Object System.Net.HttpListener
    if($AuthenticationSchemes)
    {
        $global:listener.AuthenticationSchemes = $AuthenticationSchemes
    }
    if($DefaultServiceNames)
    {
        $global:listener.DefaultServiceNames = $DefaultServiceNames
    }

    $Global:URLPrefixes |?{$_}| %{
        $AddPrefixItem=$_
        $global:listener.Prefixes.Add($_)
    }
    if ($global:listener.Prefixes -ne $null)
    {
        $Error.clear()
        $global:listener.Start()
        $ListenerStartError=$Error
    }

    Write-Host "Listening on:`n`t$($Global:URLPrefixes -join "`n`t")..."


    if (get-job -Name PeriodicRequest -ea silentlycontinue)
    {
        Stop-Job -Name PeriodicRequest
        Remove-Job -Name PeriodicRequest
    }
    Write-Host  Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(5,"http://localhost:$($RandomPort)/blank"))
                Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(5,"http://localhost:$($RandomPort)/blank"))
    write-host  Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(30,"http://localhost:$($RandomPort)/"))
                Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(30,"http://localhost:$($RandomPort)/"))
    
    [string]$LocalURL = $Global:URLPrefixes|?{$_ -like "*$env:COMPUTERNAME*"} | select -First 1
    if (-not $NoIE -and ($LocalURL -ne ''))
    {
        $Global:IEWindow = GetIEWindow -URLLike "$($LocalURL)*"
        if (-not $Global:IEWindow)
        {
            & $IE $LocalURL
            $I = 0
            While (-not $Global:IEWindow -and ($I -lt 10))
            {
                $Global:IEWindow = GetIEWindow -URLLike "$($LocalURL)*"
                $I++
            }
        }
    }
    $I = 0
    $AutoFunctionReloadCount = 0
    while ($global:listener.IsListening)
    {
        if (-not $NoIE -and ($LocalURL -ne ''))
        {
            $I++
            if (-not $Global:IEWindow.Visible)
                {
                $Global:IEWindow = GetIEWindow -URLLike "$($LocalURL)*"
                if (-not $Global:IEWindow)
                {
                    if ($I -gt 2) {return LastCall}
                }
            }
        }
        ProcessAsynchronousOperationArray -AsynchronousOperationArray $AsynchronousOperationArray
        $AutoFunctionReloadCount++
        if ($AutoFunctionReloadCount -gt 10)
        {
            . LoadFunctions
            $AutoFunctionReloadCount=0
        }
    }
}

process {
}

End {
    LastCall 2> $null
    Stop-Job -Name PeriodicRequest*
    Remove-Job -Name PeriodicRequest*
}
