param (
    [switch]$Install,
    $ServiceAccountCredential,
    [uint16[]]$Ports
)

    if ($Install)
    {
        $ServiceAccountName = $ServiceAccountCredential.username
        $PasswordGen = $ServiceAccountCredential.Password
        $Ports |Where-Object{$_}|ForEach-Object{
            $PortNumberItem = $_
            if ($ServiceAccountName -eq $null)
            {
                $ServiceAccountName = (($Script:ScriptName -replace ':' -replace '\\|\/','_' -split '' |Where-Object{$_ -match '[a-z0-9]|-|_| |\.'}) -join '') + 
                    '_Port' + 
                    $PortNumberItem
                $PasswordGen=New-RandomPassword -Length 25 -MinUpperCaseLetters 3 -MinLowerCaseLetters 3 -MinCapSpecialChars 3 -MinNumbers 3 | ConvertTo-SecureString -AsPlainText -Force
                $ServiceAccountCredential = [pscredential]::new($ServiceAccountName,$PasswordGen)
                $ADSI = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
                $ServiceAccountObject = $ADSI.Children | Where-Object {
                    $_.SchemaClassName -eq 'user' -and 
                    $_.Name -eq $ServiceAccountName 
                }
                if ( $ServiceAccountObject -eq $null)
                {
                    $ServiceAccountObject = $ADSI.Create("User",$ServiceAccountName)
                }
                $ServiceAccountObject.SetPassword($PasswordGen)
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.HomeDirectory = "$Global:Project_Root\Logs"
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.FullName = "Local User for $script:ScriptPath"
                $ServiceAccountObject.SetInfo()
                $ServiceAccountObject.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
                $ServiceAccountObject.SetInfo()
            }
            #Make a secure password that will meet most secureity standards.
            Add-UserToLoginAsBatch -UserID $ServiceAccountName
            $URLACLData = (netsh http show urlacl) -join "`n" -split '\n\n'
            $URLACLData|Where-Object{
                $_ -like "*http://+:$PortNumberItem/*"
            } | ForEach-Object{$_ -split '\n'|Where-Object{$_ -match 'Reserved URL '}} |
                ForEach-Object{$_ -split ':\s\s*'|Select-Object -Last 1} | ForEach-Object{
                write-host netsh http delete urlacl "url=$_"
                netsh http delete urlacl "url=$_"
            }
            if (-not ($URLACLData|Where-Object{$_ -like "*http://+:$PortNumberItem/*"} | Where-Object{$_ -like "*User: $ServiceAccountName*"}))
            {
                netsh http add urlacl url=http://+:$PortNumberItem/ user="$ServiceAccountName"
                netsh http add urlacl url=http://+:$PortNumberItem/+ user="$ServiceAccountName"
                [string[]]''
                $Global:URLPrefixes | Where-Object{$_} | ForEach-Object{
                    $PrefixItem = $_
                    #$Global:Routes |?{$_.name} | %{
                    #    $RoutName = "/$($_.name)" -replace '\/\/*','/'
                    #    $TestPrefix = $PrefixItem -replace ':\d\d*\/*',":$PortNumberItem$($RoutName)"
                        $TestPrefix = $PrefixItem -replace ':\d\d*\/*',":$PortNumberItem\+"
                        netsh http add urlacl ("url=$TestPrefix" -replace '') user="$ServiceAccountName"
                    #}
                }
            }
            if ((netsh advfirewall firewall show  rule "name=$ServiceAccountName" ) -match 'No rules match the specified criteria')
            {
                write-host Adding firewall rules
                netsh advfirewall firewall add rule "name=$ServiceAccountName" protocol=TCP dir=in "localport=$PortNumberItem" security=notrequired  action=allow edge=yes WebUserProfile=any 
            }
            ELSE
            {
                write-host firewall rules exist
            }
            $ScheduledTask=Get-ScheduledTask -TaskName $ServiceAccountName -ErrorAction SilentlyContinue
            $ScheduledTaskAction = New-ScheduledTaskAction -Execute cmd -Argument "/c ""$($script:ScriptPath -replace '\.ps1$','.bat')"" -Port $PortNumberItem' > ""$Global:Project_Root\Logs\$ServiceAccountName.log""" -WorkingDirectory "$Global:Project_Root\Logs"
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
            $ScheduledTask = Register-ScheduledTask -TaskName "$ServiceAccountName" @SCheduledTaskSplat 
            icacls $Global:Project_Root /grant "$($ServiceAccountName):(OI)(CI)RX"
            icacls "$Global:Project_Root\Logs" /grant "$($ServiceAccountName):(OI)(CI)M"
        }
    }

