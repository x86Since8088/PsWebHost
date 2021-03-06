$Global:ErrorActionPreference = 'Continue'
$Script:ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Web | out-null

    Function Set_CacheControl {
        param (
            [ValidateSet('public','private','no-cache','no-store')]
            $Policy='private',
            [int]$MaxAge=60
        )
        #http://condor.depaul.edu/dmumaugh/readings/handouts/SE435/HTTP/node24.html
        $Item = "$Policy, max-age=$MaxAge"
        $response.Headers.Add("Cache-Control", $Item)
        $response.Headers.Item("Cache-Control") = $Item
    }
    $RouteTable=@{}
    $Routes = new-object System.Collections.ArrayList
    &{
        new-object psobject -Property @{Name = "/";            Value = {Set_CacheControl -Policy private -MaxAge 300  ;return (Launch_Application)};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "ola";          Value = {Set_CacheControl -Policy private -MaxAge 5    ;return '<html><body>Hello world!</body></html>' };Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "process";      Value = {Set_CacheControl -Policy private -MaxAge 300  ;return & {(gwmi win32_process -Property * | ConvertTo-Html)}};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "go";           Value = {Set_CacheControl -Policy private -MaxAge 300  ;return (Launch_Application)};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "Home";         Value = {Set_CacheControl -Policy private -MaxAge 10   ;return (Launch_Application)};Authentication = 'basic'}
        new-object psobject -Property @{Name = "bauth";        Value = {Set_CacheControl -Policy private -MaxAge 0    ;return (Launch_Application)};Authentication = 'basic'}
        new-object psobject -Property @{Name = "wiauth";       Value = {Set_CacheControl -Policy private -MaxAge 60   ;return (Launch_Application)};Authentication = 'IntegratedWindowsAuthentication'}
        new-object psobject -Property @{Name = "time";         Value = {Set_CacheControl -Policy private -MaxAge 1    ;return ((get-date|out-string))};Authentication = 'Anonymous'}
        #Put a /blank listener on each HTTPListere
        new-object psobject -Property @{Name = "blank";        Value = {Set_CacheControl -Policy private -MaxAge 5    ;return ""};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "data";         Value = {Set_CacheControl -Policy private -MaxAge 10   ;return (Launch_Application)};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "/favicon.ico"; Value = {Set_CacheControl -Policy public -MaxAge 300   ;return (get-content -Encoding byte ("$Script:ScriptFolder" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "img";          Value = {
            Set_CacheControl -Policy public -MaxAge 300   ;return (get-content -Encoding byte ("$Script:ScriptFolder" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))};Authentication = 'Anonymous'
        }
        new-object psobject -Property @{Name = "css";          Value = {Set_CacheControl -Policy public -MaxAge 30    ;return (get-content ("$Script:ScriptFolder" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))
        };Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "js";           Value = {Set_CacheControl -Policy public -MaxAge 300   ;
            return (get-content ("$Script:ScriptFolder" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))
        };Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "content";          Value = {Set_CacheControl -Policy public -MaxAge 30    ;return (get-content ("$Script:ScriptFolder" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))
        };Authentication = 'Anonymous'}
    } | ?{$_.name} | %{
        if (-not ($RouteTable[$_.name]))
        {
            $RouteTable.add($_.name,$routes.Add($_))
        }
    }
    gci "$Script:ScriptFolder\content" |?{$_.psiscontainer} | %{
            new-object psobject -Property @{Name = $_.Name;          Value = {Set_CacheControl -Policy public -MaxAge 30    ;return (get-content ("$Script:ScriptFolder\content)" + ([Web.HttpUtility]::UrlDecode($Global:LocPath) -replace '\/','\')))
            };Authentication = 'Anonymous'}
    } | ?{$_.name} | %{
        if (-not ($RouteTable[$_.name]))
        {
            $RouteTable.add($_.name,$routes.Add($_))
        }
        Else
        {
            write-warning -Message "Route in '$Script:ScriptFolder\content\$($_.name))' cannot be added because it conflicts with a previously defined route."
        }
    }

    function AddhttpListener {
        Param (
            $Authentication,
            $Prefix
        )
        $listenerObject = $global:ListenerTable[$Authentication]
        if ($listenerObject-eq $null)
        {
            $listenerObject = New-Object System.Net.HttpListener
        }
        $listenerObject.AuthenticationSchemes = $Authentication
        $Prefix|?{$_}|%{$listenerObject.Prefixes.Add($_)}
        $Lookup = $global:ListenerTable[$Authentication]
        if ($Lookup -eq $Null)
        {
            $global:ListenerTable.add($Authentication,$global:ListenerArray.add($listenerObject))
        }
        ELSE
        {
            #mighr not be necessary because the array item might is probably reflective.
            #$global:ListenerArray[$Lookup] = $listenerObject
        }
    }

    Function GetHTTPListener {
        param (
            $Authentication
        )
        $Global:ListenerArray[$Global:ListenerTable[$Authentication]]
    }

    Function LoadListenersWithRoutes {
        $Global:URLPrefixes | ?{$_} | %{
            $Prefixitem = $_
            $routes |?{$_.name}|%{
                $RouteItem = $_
                $NewPrefix = ($Prefixitem -replace '/*\s*$'+ '/') + ($RouteItem.name -replace '/*\s*$'+ '/') + '/'
                AddhttpListener -Authentication $RouteItem.Authentication -Prefix $NewPrefix
            }
        }
    }

    Function ReturnFile {
        param(
            [string]$URLPath = $Global:LocPath
        )
        $LocalPath = "$Script:ScriptFolder" + ($URLPath -replace '\/','\')
        
        get-content -Encoding byte ($LocalPat)
    }

    Function Get_Theme {
        param (
            $Name,
            $Type
        )
        gci "$Script:ScriptFolder\css" "Theme_$Name_*" | ?{$_.psiscontainer} | %{
            gci $_.FULLNAME | ?{-not ($_.fullpath -match '\\archive\\| \- copy\.')} | ?{
                ($_.name -split '\.')[-1] -eq $Type
            } | %{
                $File = $_
                $WebPath = $File.FullName.replace("$Script:ScriptFolder\",'').replace('\','/')
                switch ($Type)
                {
                    'js' {
                        Write_Tag -Tag Script -TagData "SRC=""$WebPath"" type=""text/javascript""" 
                    }
                    'css' {
                        Write_Tag -Tag link -TagData "rel='stylesheet' type='text/css' href='$WebPath'"
                    }
                    'HTMLMenu' {
                        & "$Global:ScriptFolder\Apps\Menu.ps1" -AppArguments (new-object psobject -Property @{
                            Name="Command";
                            Value='ControlPannel'
                        })
                    }
                    default {GC $File.FULLNAME }
                }
            }
        }
    }

    Function Update_Theme {
        param (
            $Name
        )
        [array]$Global:Include_Java = Get_Theme -Name $Name -Type js
        [array]$Global:Include_CSS = Get_Theme -Name $Name -Type css
        [array]$Global:Include_HTML_Menu = Get_Theme -Name $Name -Type HTMLMenu 
        [array]$Global:Include_HTML_Header = Get_Theme -Name $Name -Type HTMLHeader
        [array]$Global:Include_HTML_Footer = Get_Theme -Name $Name -Type HTMLFooter
        [array]$Global:Include_HTML_Navigation = Get_Theme -Name $Name -Type HTMLNavigation
    }

    Function LastCall {
        if ($Global:IEWindow.Application)
        {
            $Global:IEWindow.Quit() 2>$null
            $Global:IEWindow = $Null
        }
        if ($global:listener)
        {
            $Global:Context = $global:listener.GetContext()
            $Global:Context.Response.StatusCode = 404
            $Global:Context.Response.Close()
            $Global:Listener.Prefixes.Clear()
            $Global:Listener.stop()
            $Global:Listener.Prefixes | %{$_} | ?{$_} | %{$Listener.Prefixes.Remove($_)} 2>$null
            $Global:Listener.Close()
            $Global:Listener.Dispose()
        }
        Remove-Variable listener                   -Scope global -ErrorAction silent -Force
        Remove-Variable listener_Anonymous         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_BasicAuth         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_WindowsIntegrated -Scope global -ErrorAction silent -Force
    }
    
    Function GetRandomUnusedTCPPort ([int]$Low = 982,[int]$High=984){
    #Get a random TCP Port that is not used or within a narrow grouping.
    $Netstat = netstat -n -a
    $High++
    $low--
    $LocalPorts = &{$low;$Netstat | %{[int]($_ -split '\s\s*' -match ":" -split ":")[1]}; $High } |sort -Unique |?{($_ -le ($High)) -and ($_ -ge ($Low))}
    $LargestopenPortRange = $LocalPorts | %{
        $A = $_
        if ($B) {new-object psobject -Property @{Start=($B+1);Stop=($A-1);Gap=($A-1-$B)}}
        $B = $A
    } | sort gap -Descending | select -First 1
    $A=0;$B=0
    $LargestopenPortRange | %{
        if ($_.Start -eq $_.Stop)
        {
            $_.Start
        }
        ELSEif ($_.Start -lt $_.Stop)
        {
            get-random -Minimum $_.Start -Maximum $_.stop
        }
        ELSE
        {
            return (Write-Error -message "No ports available in range")
        }
    }
}

    function GetIEWindow {
        <#
        .Synopsis
            Returns existing Internet Explorer windows.
        #>
        param (
            $URLMatches,
            $URLLike
        )
        $app = new-object -com shell.application
        if ([bool]$URLMatches)
        {
            $app.windows() | where {$_.Type  -eq "HTML Document" -and $_.LocationURL -match $URLMatches} 
        }
        ELSEIF ([bool]$URLLike)
        {
            $Result = $app.windows() | where {$_.Type  -eq "HTML Document" -and $_.LocationURL -Like $URLLike} 
            If (-not $Result)
            {
                $oIE=new-object -com internetexplorer.application
                $oIE.Navigate($URLLike -replace '\*$')
                $oIE.visible = $True
                $oIE
            }
            ELSE
            {
                $Result
            }
        }
        ELSE
        {
            $app.windows() | where {$_.Type  -eq "HTML Document"}
        }
    }
    
    Function Write_FavIcon.ico {
        param (
            $IconFile = (gci "$Script:ScriptFolder\IMG" "favicon*.ico" | sort length -Descending | select -First 1 | %{$_.fullname})
        )
        $ImageFormat = ($IconFile -split '\.')[-1]
        Get-Content $IconFile -TagData "rel='shortcut icon'"
    }
    
    Function Write_Img_Base64Encoded {
        param (
            $Tag = "IMG",
            $TagData,
            $ImageFormat = "bmp",
            $File,
            $Bytes
        )
        if ($File)
        {
            $BitmapBase64 = [convert]::ToBase64String((get-content -Path $File -Encoding byte))
        }
        ELSE
        {
            $BitmapBase64 = [convert]::ToBase64String($Bytes)
        }
        return ("<$Tag $TagData src='data:image/$ImageFormat;base64,"+$BitmapBase64+"' alt='Embeded Image'/>")
    }

    function Indent {
        param (
            [int]$Indent,
            [string[]]$Text
        )
        begin {
            if ($Text)
            {
                $Text -split "`n" | %{"`n" + ((0..($Indent))|%{"`t"})+$_}
            }
        }
        process {
            $_ -split "`n" | ?{$_} | %{"`n" + ((0..($Indent))|%{"`t"})+$_} 
        }
        end {}
    }
    
    function StopTable {
        if ($Global:InTable)
        {
            if ($Global:TableData)
            {
                $Global:TableData
                Remove-Variable TableData -Scope Script
            }
            
            "</TBODY></TABLE>"
            $Script:TableInclude_Old = $Null
            $Global:InTable = $False
        }
    }

    function StartTable {
        param (
            [string]$TagData = "border=1 style=""font-size:12px;background-color:white;color:black;""",
            [array]$TableInclude
        )
        if ($Script:TableInclude_Old -and ("$TableInclude" -ne "$Script:TableInclude_Old"))
        {
            StopTable
        }
        $Global:TableData = New-Object system.collections.arraylist
        if ($TagData -notmatch '^Name=|\sName=') 
        {
            [string]$TableName = "DataSet_$($TableInclude -join ",")"
            $TagData = 'Name='+$TableName+' '+$TagData
        }
        if (-not $Global:InTable) {
            $Global:InTable = $True
            '<Table '+$TagData+'>'+"`n"+'<THEAD><TR>'+(($TableInclude |?{$_}| %{'<TH>'+$_+'</TH>'}) -join "") + '</TR></THEAD>'+"`n<TBODY>"
        }
        $Script:TableInclude_Old = $TableInclude
    }
    
    function Write_Tag {
        param (
            $Tag,
            $TagData,
            $Content,
            [int]$Indent = 1
        )
        begin {
            $O = '<'+$Tag+' '+$TagData+'>' + (($content -split "`n" | ?{$_}) -join "`n")
        }
        Process {
            $O = $O + (($_ -split "`n" ) -join "`n")
        }
        End {
            $O = $O + '</'+$Tag+'>'
            $O
        }
    }

    function Write_Table {
        param (
            $Inputobject,
            [string]$TagData = "border=1 style=""font-size:12px;background-color:white;color:black;""",
            [array]$TableInclude
        )
        begin {
            [array]$Data = $Inputobject
        }
        process {
            $_ | ?{$_} | %{
                [array]$Data = $Data + $_
            }
        }
        End {
            if (-not $TableInclude)
            {
                $TableInclude = Get-Member -InputObject $Data[0] -MemberType properties | %{$_.name}
            }
            StartTable -TagData $TagData -TableInclude $TableInclude
            $Data | ?{$_} | %{
                $O = $_; 
                Write_Tag -Tag "TR" -Content ($TableInclude | %{
                    Write_Tag -Tag "Td" -Content ($O.($_))}) | %{$Global:TableData.add($_)
                } | out-null
            }
            StopTable
        }
    }
    
    Function GzipResponse {
        param ($Buffer)
        $MS  = New-Object system.io.MemoryStream 
        $Zip = New-Object System.IO.Compression.GZipStream  $ms, ([IO.Compression.CompressionMode]::Compress), $true
        $zip.Write($buffer, 0, $buffer.Length);
        $zip.Close()
        $ms.ToArray();
        $ms.Close()
        $Script:response.AddHeader("Content-Encoding", "gzip");
    }
    
    function Write_Script {
        param ($TagData,$Content)
        '<Script '+$TagData+'>'+"`n"
        $Content+"`n"
        '</Script>'
    }

    function Write_Style {
        param ($TagData,$Content)
        '<Style '+$TagData+'>'+"`n"
        indent -Indent 1 -Text $Content
        '</Style>'
    }
    
    function Write_Head {
        Write_Tag -Tag 'Head' -Content ( &{
            $Global:Include_CSS 
            $Global:Include_Java
        })
    }
    
    function Write_Body {
        param (
            $TagData = ("STYLE=""font:12 pt arial; color:white;background-color:#333333;"" onload=""main"""),
            $Content,
            [int]$indent = 1
        )
        indent -Indent $Indent -Text ('<BODY '+$TagData+'>')
        Write_Tag -Tag nav -TagData "class='menu'" -content (. "$Script:ScriptFolder\Apps\Menu.ps1")
        Write_Tag -Tag header -TagData "class='header'" -content (&{
            $Global:Include_HTML_Header
            Write_Tag -Tag SPAN -TagData "class='Navigation'" -content $Global:Include_HTML_Navigation
        })
        Write_Tag -Tag article -TagData "class='MainBody'" -content $Content
        Write_Tag -Tag footer -TagData "class='footer'" -content $Global:Include_HTML_Footer
        indent -Indent $Indent -Text '</BODY>'
    }
    
    function Write_HTML {
        param ($TagData,$Content)
        '<HTML '+$TagData+'>'
        ''
        Write_Head
        ''
        write_body -Content $content
        ''
        '</HTML>'
    }
    
    function Launch_Application {
        param (
            $User = $global:Context.user,
            $Query = $global:Context.Request.Url.Query,
            $ApprovedNames = ("Navigate","Help","Launch","Eleveted","look","App")
        )
        if ($Global:ReaderString)
        {
            $Arguments = $Global:ReaderString | ?{$_}| %{$S = $_ -split "=(.*)" |%{[Web.HttpUtility]::UrlDecode($_)};$Name = $S[0];$Value = $S[1];new-object psobject -Property @{Name=$Name;Value=$Value} }
        }
        ELSE
        {
            $Arguments = $global:Context.Request.Url.Query -replace '\%22','"' -split "\?"| ?{$_} | %{$S = $_ -split "=(.*)";$Name = $S[0];$Value = $S[1];new-object psobject -Property @{Name=$Name;Value=$Value} }
        }
        $RequestedApp = $Arguments | ?{$_.name -eq "App"} | select -First 1
        if (-not $RequestedApp) {$RequestedApp = @{Name="App";Value="ControlPannel"}}
        $App = $script:Apps | ?{$_.name -eq ($RequestedApp.value + ".ps1")} | select -First 1
        #$App = $script:Apps | ?{$A = $_;$RequestedApp.value -split ',' | ?{$R = $_;$A.name -eq ($R + ".ps1")}} #| select -First 1
        if ($App)
        {
            $ApprovedArgs = & $App.fullname -GetApprovedArgs
            $AppArguments = $Arguments | ?{$A = $_.name;$ApprovedArgs | ?{$_ -eq $A}}
            return (. $App.fullname -AppArguments $AppArguments)
        }
    }

    Function AsHTML {
        param(
            [array]$InputObject
        )
        begin {
            function ProcessInputObject {
                param ($InputObject)
                if (($InputObject.gettype().name -eq "string") -and ($InputObject[0] -eq "<"))
                {
                    $InputObject
                }
                ELSE
                {
                    IF ([bool]$Global:HTable_Data)
                    {
                        if ($InputObject.HTMLOutputFormat -ne "HTABLE")
                        {
                            Write_HTable -Inputobject $Global:HTable_Data
                            $Global:HTable_Data = new-object system.collections.arraylist
                        }
                    }
                    ELSE
                    {
                        $Global:HTable_Data = new-object system.collections.arraylist
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "HTABLE")
                    {
                        $Global:HTable_Data.add(($InputObject | select -ExcludeProperty HTMLOutputFormat))|Out-Null
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "Tag")
                    {
                        write_tag -Tag $InputObject.tag -TagData $InputObject.TagData -Content $InputObject.Content
                    }
                    ELSE
                    {
                        switch ($InputObject.gettype().name)
                        {
                            "string" {
                                stoptable
                                '<P data_type="String">' + $InputObject + '</P>'
                            }
                            default {
                                $Properties = Get-Member -InputObject $InputObject -MemberType properties | %{$_.name}
                                if ($BuildHeaders)
                                {
                                    $Headers = $Properties 
                                }
                                IF (-not $Global:InTable -or ("$Properties" -ne "$Script:TableInclude_Old")) 
                                {
                                    starttable -TableInclude $Properties | %{$Global:TableData.add($_)} | out-null
                                }
                                Write_Tag -Tag "TR" -Content (
                                    $Properties | %{
                                            Write_Tag -Tag "Td" -Content ($InputObject.($_))
                                        }
                                ) | %{$Global:TableData.add($_)} | out-null
                            }
                        }
                    }
                }
            }
            $InputObject | ?{$_} | %{
                ProcessInputObject -InputObject $_
            }
        }
        process {
            if ($_)
            {
                ProcessInputObject -InputObject $_
            }
        }
        end {
            StopTable
        }
    }
    
    Function Write_HTable {
        Param (
            [array]$Inputobject,
            [array]$Property,
            $RowTitleProperty
        )
        begin {
            [array]$Data = $Inputobject | ?{$_}
        }
        process{
            $_ | ?{$_} | %{$Data = $Data + $_}
        }
        end {
            if ($Data)
            {
                if ($Property) 
                {
                    $Headers = $Property
                }
                ELSE
                {
                    $Property = $Data | select -First 5 | %{Get-Member -InputObject $_ -MemberType Property | %{$_.name} | ?{$_ -ne 'HTMLOutputFormat'}}
                    $PropertyNew = $Property | ?{$_} | %{
                        $P = $_;
                        $P;
                        $Property = $Property | ?{$_ -ne $P}
                    }
                    $Property = $PropertyNew
                    $Headers = (1..($Data.count))|%{"Value$_"}
                }
                $KeyProperty = $Null
                if ($RowTitleProperty)
                {
                    $KeyProperty = $RowTitleProperty
                    $Headers = $Data | %{$_.($KeyProperty)}
                }
                ELSE
                {
                    "pscomputername","computername","__Server","Date","time" | ?{($Data | select -skip 0 -First 1).pscomputername} | select -First 1| %{
                        $KeyProperty = $_
                        $Headers = $Data | %{$_.($KeyProperty)}
                    }
                }
                [array]$TableInclude = 'Property'
                $TableInclude = $TableInclude + $Headers | ?{$_}
                $Property | %{
                    $PropertyItem = $_
                    $I = 0
                    $Record = New-Object psobject -Property @{Property=$PropertyItem}
                    $Headers | ?{$_} | %{
                        $HeaderItem = $_
                        #$DataItem = $Data[$I]
                        Add-Member -InputObject $Record -MemberType noteproperty -name $HeaderItem -Value ((($Data | select -skip $i -First 1).($PropertyItem) | out-string) -replace '^\s\s*|\s\s*$')
                        $I++
                    }
                    $Record | select -Property $TableInclude
                } |Write_Table -TableInclude $TableInclude
                
            }
        }
    }
    
    Function PeriodicRequest {
        Param (
            [int]$Interval = 5,
            [string]$url
        )
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$true

        while ($True)
        {
            
            ($URL + $Args)|?{$_ -match "https*:\/\/"}  | %{
                $wc.DownloadString("$_")|out-null
            }
            Sleep $Interval
        }
    }
    
    function IsLocalRequest {
        $Query = $global:Context.Request.Url
    }

    Function Schedule_Disposal {
        param (
            [datetime]$DisposeAfter,
            $Object,
            [scriptblock]$AfterDisposalAction
        )
        if ($DisposeAfter -and $Object)
        {
            $Global:Dispose = [array]$Global:Dispose + (new-object psobject -Property @{
                DisposeAfter=$DisposeAfter;
                Object=$Object;
                AfterDisposalAction=$AfterDisposalAction
            })
        }
        $now = Get-date
        $Global:Dispose | ?{$_.DisposeAfter} | ?{$_.DisposeAfter -le $now} | %{
            $_.object.dispose()
            & $_.AfterDisposalAction
        }
        $Global:Dispose = $Global:Dispose | ?{$_.DisposeAfter -gt $now}
    }

    #Function AsHTML {
    <#
        param(
            [array]$InputObject
        )
        begin {
            function ProcessInputObject {
                param ($InputObject)
                if (($InputObject.gettype().name -eq "string") -and ($InputObject[0] -eq "<"))
                {
                    $InputObject
                }
                ELSE
                {
                    IF ([bool]$Global:HTable_Data -and ($InputObject.HTMLOutputFormat -ne "HTABLE"))
                    {
                        Write_HTable -Inputobject $Global:HTable_Data
                        $Global:HTable_Data = new-object system.collections.arraylist
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "HTABLE")
                    {
                        $Global:HTable_Data.add(($InputObject | select -ExcludeProperty HTMLOutputFormat))|Out-Null
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "Tag")
                    {
                        write_tag -Tag $InputObject.tag -TagData $InputObject.TagData -Content $InputObject.Content
                    }
                    ELSE
                    {
                        switch ($InputObject.gettype().name)
                        {
                            "string" {
                                stoptable
                                '<P data_type="String">' + $InputObject + '</P>'
                            }
                            default {
                                $Properties = Get-Member -InputObject $InputObject -MemberType properties | %{$_.name}
                                if ($BuildHeaders)
                                {
                                    $Headers = $Properties 
                                }
                                IF (-not $Global:InTable -or ("$Properties" -ne "$Script:TableInclude_Old")) 
                                {
                                    if ($Global:TableData.count -eq $null)
                                    {
                                        $Global:TableData = New-Object system.collections.arraylist
                                    }
                                    starttable -TableInclude $Properties | %{$Global:TableData.add($_)} | out-null
                                }
                                Write_Tag -Tag "TR" -Content (
                                    $Properties | %{
                                            Write_Tag -Tag "Td" -Content ($InputObject.($_))
                                        }
                                ) | %{$Global:TableData.add($_)} | out-null
                            }
                        }
                    }
                }
            }
            $InputObject | ?{$_} | %{
                ProcessInputObject -InputObject $_
            }
        }
        process {
            if ($_)
            {
                ProcessInputObject -InputObject $_
            }
        }
        end {
            StopTable
        }
    }
    #>

    Function IsolateduserSession {
        param (
            [string]$User,
            [string]$Purpose = 'Sensitive'
        )
        $Pssession = Get-PSSession -Name "$($user)_$($Purpose)" -ErrorAction SilentlyContinue
        if ($global:context.User.Identity.Password -and -not $Pssession)
        {
            $Cred = new-object -typename System.Management.Automation.PSCredential `
                -argumentlist $username, ($global:context.User.Identity.Password | ConvertTo-SecureString -AsPlainText -Force)
            New-PSSession -Name "$($user)_$($Purpose)" -Credential $Cred -ErrorAction Continue
        }
    }

    Function ProcessWebParams {
        param ($AppArguments)
        $AppArguments | ?{$_.name -match '^Param'} | %{
            $AppArgumentItem = $_
            if ($_.Name -eq 'ParamName') 
            {
                $ParamName = $_.value
            }
            elseif ($_.name -eq "ParamReset")
            {
                $Params = @{}
            }
            elseif ($_.name -eq "ParamSet")
            {
                if (-not $ParamName)
                {
                    'ParamSet passed without ParamName.'
                }
                ELSE
                {
                    if ($params.Contains($ParamName))
                    {
                        $params.Item($ParamName) = $_.Value
                    }
                    ELSE
                    {
                        $Params.Add($ParamName,$_.Value)
                    }
                }
            }
            elseif ($_.name -eq "ParamAdd")
            {
                if (-not $ParamName)
                {
                    'ParamAdd passed without ParamName.'
                }
                ELSE
                {
                    [array]$V = $Params.($ParamName)
                    $V = $V + $_.Value
                    if ($params.Contains($ParamName))
                    {
                        $params.Item($ParamName) = $V
                    }
                    ELSE
                    {
                        $Params.Add($ParamName,$V)
                    }
                }
            }
            elseif ($_.name -eq "ParamRemove")
            {
                {
                    'ParamAdd passed without ParamName.'
                }
                ELSE
                {
                    if ($params.Contains($ParamName))
                    {
                        $params.Remove($ParamName)
                    }
                }
            }
        }
    }

    Function Add_Cookie {
        param (
            $Name,
            $Value,
            $Comment,
            $CommentUri,
            $HttpOnly,
            $Discard,
            $Version,
            $TimeStamp,
            $Domain,
            $Expires = ((get-date).AddSeconds(60).ToUniversalTime().ToString() + ' GMT'),
            $Secure,
            $Port,
            $Path
        )
        $Cookie = New-Object system.Net.Cookie
        if ($Name) {$Cookie.Name = $Name}
        if ($Value) {$Cookie.Value = $Value}
        if ($Comment) {$Cookie.Comment = $Comment}
        if ($CommentUri) {$Cookie.CommentUri = $CommentUri}
        if ($HttpOnly) {$Cookie.HttpOnly = $HttpOnly}
        if ($Discard) {$Cookie.Discard = $Discard}
        if ($Version) {$Cookie.Version = $Version}
        if ($TimeStamp) {$Cookie.TimeStamp = $TimeStamp}
        if ($Domain) {$Cookie.Domain = $Domain}
        if ($Expires) {$Cookie.Expires = $Expires}
        if ($Secure) {$Cookie.Secure = $Secure}
        if ($Port) {$Cookie.Port = $Port}
        if ($Path) {$Cookie.Path = $Path}
        #$global:Context.Response.AppendCookie($Cookie)
        $global:Context.Response.SetCookie($Cookie)
    }

    Function Add_Cookie_SessionID {
        param(
        )
        $ExistingCookie = $Global:Context.Request.Cookies.Item('SessionID')
        if (-not $ExistingCookie)
        {
            Add_Cookie -Name SessionID `
            -Domain *.skarke.net,skarke.net,localhost `
            -Value (get-date).ToFileTimeUtc() `
            -Expires  ((get-date).AddSeconds(3600).ToUniversalTime().ToString() + ' GMT') `
        }
    }

    Function Get_Cookie_SessionID {
        $global:Context.Request.Cookies | ?{$_.Name -eq "SessionID"}
    }

    Function Get_UserSession ($SessionCookie) {
        $SessionID = $SessionCookie.Value
    }


    if ($Global:UserSessionTable -eq $null) {$Global:UserSessionTable = @{}}
    if ($Global:UserSessionArray -eq $null) {$Global:UserSessionArray = new-object System.Collections.ArrayList}
    Function New_UserSession {
    [cmdletbinding()]
    param (
        $SessionCookie,
        [switch]$Force
    )
        if (-not $SessionCookie) {return}
        $SessionID = $SessionCookie.Value
        if ($SessionID)
        {
            $SessionIndex = $Global:UserSessionTable[$SessionID]
        }
        ELSE
        {$SessionIndex=$null}
        if ($SessionIndex -eq $null) 
        {$SessionItem=$null}
        ELSE
        {
            $SessionItem = $Global:UserSessionArray[$LU]
        }
        if ($LU -and -not $force)
        {
            Write-warning -Message 'New_UserSession was used, but $Global:UserSessionTable contains an existing session.' 
        }
        ELSEIF ($LU -and $Force)
        {
            Write-Warning -Message "resetting session $SessionIndex - `n$($session)"
            $Global:UserSessionArray[$SessionIndex].PrivateSessions |?{$_} |%{$_.dispose()}
            $NewuserSession=New_UserSessionObject -SessionCookie $SessionCookie  

            $Global:UserSessionArray[$SessionIndex]=$NewuserSession
        }
        ELSE
        {
            $NewuserSession=New_UserSessionObject -SessionCookie $SessionCookie 
            $Global:UserSessionTable.add($SessionID,$Global:UserSessionArray.add($NewuserSession))
            return $NewuserSession
        }
    }

    Function New_UserSessionObject {
    param (
        [System.Net.Cookie]$SessionCookie,
        [string]$UserAgent = $Global:Context.Request.UserAgent,
        [psobject[]]$GeoIPData = (
            . {
                if ($Context.Request.RemoteEndPoint -ne $null) 
                {Get-GeoIP -IP $Context.Request.RemoteEndPoint.ToString()}
            }
        ),
        [hashtable]$CredentialSet = (
            @{
                AD=[pscredential]
                WebLocal=[pscredential]
                ADSI=[pscredential]
                Google=[pscredential]
                Azure=[pscredential]
                O365=[pscredential]
                Facebook=[pscredential]
            }
        ),
        [psobject]$Profile
    )
        $Object=New-Object psobject -Property ([ordered]@{
            SessionCookie=[System.Net.Cookie]$SessionCookie
            UserAgent=[string]$UserAgent
            UserAgentHistory=[System.Collections.ArrayList]::new()
            GeoIPData=[psobject[]]$GeoIPData
            CredentialSet=$CredentialSet
            Password=[securestring]$Password
            Profile=[psobject]$Profile
            PrivateSessions=@()
            Jobs=@()
        })
        if ($UserSessionObject_UserAgentHistory_Update -eq $null)
        {
            New-Variable -Name UserSessionObject_UserAgentHistory_Update -Option AllScope,Constant -Force -Value {
                param ($NewUserAgent)
                if ($This.UserAgent -ne $NewUserAgent)
                {
                $This.UserAgent = $NewUserAgent
                $This.UserAgentHistory.add(
                    (
                        New-Object psobject -Property ([ordered]@{Date=(get-date);UserAgent=$NewUserAgent})
                    )
                )>$null
                }
            }
        }
        $Object | Add-Member -MemberType ScriptMethod -Force -Name UpdateUserAgent -Value $UserSessionObject_UserAgentHistory_Update -PassThru
        
    }

    Function Get_Pipelines {
        
    }

    Function CleanupAsynchWriteOperations ($AsynchronousOperationArray) {
        $I=0
        $AsynchronousOperationArray | %{
            $AsynchronousOperationCleanupItem = $_
            if (
                $AsynchronousOperationCleanupItem.Response.IsCompleted -or 
                $AsynchronousOperationCleanupItem.Response.IsCanceled -or 
                $AsynchronousOperationCleanupItem.Response.IsFaulted
            )
            {
                if ($AsynchronousOperationCleanupItem.Response)
                {
                    if ($AsynchronousOperationCleanupItem.Response.close) 
                    {
                        $AsynchronousOperationCleanupItem.Response.close()
                    }
                    $AsynchronousOperationCleanupItem.Response.Dispose()
                    $Script:AsynchronousOperationArray.RemoveAt($I) > $Null
                    $I--
                }
            }
            $I++
        }
        if ($I -gt 1) {write-host AsynchronousOperationArray count is $I}
    }

    Function CleanupResponseArray {
        for ($RI=0;$RI -lt $responseArray.count;$RI++)
        {
            #write-progress -Activity CleanupResponseArray -PercentComplete ((100 / $responseArray.count) * $RI)
            $RAItem = $Global:responseArray.item($RI)
            #$RAItem.OutputStream.FlushAsync() 2> $null
            if ($RAItem.OutputStream -ne $null)
            {
                if ($RAItem.OutputStream.close() 2> $null)
                {
                    $RAItem.OutputStream.dispose() 2> $null
                }
            }
            if ($RAItem -ne $null)
            {
                try {
                    $RAItem.close()
                    $RAItem.dispose() 2> $null
                    $Global:responseArray.RemoveAt($RI) 2> $null
                    $RI--
                }
                catch {}
            }
            ELSE
            {
                $Global:responseArray.RemoveAt($RI) 2> $null
                $RI--                
            }
        }
        write-host AsynchronousResponseArray count is $RI
    }

    Function ProcessAsynchronousOperationArray {
        param (
            $AsynchronousOperationArray
        )
        CleanupAsynchWriteOperations
        #ProcessContext
        ProcessContext
    }

    Function ProcessContext {
        param (
            [psobject]$global:SessionObject = (
                new-object psobject -Property @{
                    Context=$Global:listener.getcontext()
                }
            ),
            $Global:Context = $global:SessionObject.context
        )
        IF ($Global:Context.Request)
        {
            if ($Global:Context.Request.Url.LocalPath -like '/blank*')
            {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('')
                $Global:Context.response.ContentLength64 = $buffer.Length
                $Global:Context.response.OutputStream.Write($buffer, 0, $buffer.Length)
                #$AsynchronousOperationArray.add($global:SessionObject)
                $Global:Context.response.OutputStream.Close()
                $Global:Context.response.Close()
                return
            }
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name context -Value $Global:Context -Force
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name requestUrl -Value $Global:Context.Request.Url -Force
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name response -Value $Global:Context.Response -Force
            $Response=$Global:Context.Response
            $global:SessionObject.response = $Response
            $global:SessionObject.response.KeepAlive = $True
            $global:SessionObject.response.SendChunked = $False
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name WebRequest -Value $Global:Context.Request -Force
            $WebRequest = $Global:Context.Request
            switch ($global:SessionObject.WebRequest.HttpMethod)
            {
                'post'
                {
                    $Reader = new-object System.IO.StreamReader $WebRequest.InputStream,$WebRequest.ContentEncoding
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name Reader -Value $Reader -Force
                    $global:ReaderString = $Reader.ReadToEnd() -split '\&'
                    $PostText = $global:ReaderString|?{$_}|%{[system.web.httputility]::UrlDecode($_)}
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name ReaderString -Value $global:ReaderString -Force
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name PostText -Value $PostText -Force
                }
                'get'
                {
                    $global:ReaderString = $null
                    $PostText = $null
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name ReaderString -Value $global:ReaderString -Force
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name PostText -Value $PostText -Force
                }
                default
                {
                    $global:ReaderString = $null
                    $PostText = $null
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name ReaderString -Value $global:ReaderString -Force
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name PostText -Value $PostText -Force
                }

            }

            
         
            $localPath = $global:SessionObject.requestUrl.LocalPath
            #$route = $routes.Get_Item($global:Context.Request.Url.LocalPath)
            $Global:LocPath = ($localPath -replace '\/$|\\$')
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name LocPath -Value $Global:LocPath -Force
        
            $Global:LocPathSplit = ($Global:LocPath -split '\?')[0] -split '\/|\\'
            $RootRoute = $Global:LocPathSplit[1]
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name RootRoute -Value $RootRoute -Force
            $Global:LocPath = $Global:LocPathSplit -join '/'
            if (-not $RootRoute) {$RootRoute = 'Home'}
            #$route = $routes.GetEnumerator() | ?{$_.name -eq $RootRoute} | select -First 1
            $RouteIndex=$RouteTable[$RootRoute]
            if ($RouteIndex)
            {
                $Route = $Routes[$RouteIndex]
            }
            ELSE
            {
                $Route = $null
            }
            
            Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name route -Value $route -Force

            if ($route -eq $null)
            {
                $global:SessionObject.response.StatusCode = 404
                $global:SessionObject.response.OutputStream.Close()
                $global:SessionObject.response.close()
            }
            elseif ($route.name -match '^(img)$')
            {
                [byte[]]$buffer = & $route.value
                if ($buffer.Length -gt 0)
                {
                    $global:SessionObject.response.ContentType = 'Image/' + ([string]([array]($Global:LocPathSplit[-1] -split "\."))[-1]).ToUpper()
                    $global:SessionObject.response.ContentType
                    $global:SessionObject.response.ContentLength64 = $buffer.Length
                    $global:SessionObject.response.headers.add('Content-Length: ' + $buffer.Length)
                    $global:SessionObject.response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
                    $AsynchronousOperationArray.add($global:SessionObject)
                }
            }
            else
            {
                $SessionCookie=Get_Cookie_SessionID
                $UserSession = Get_UserSession -Session $SessionCookie
                if (-not $SessionCookie) {
                    $SessionCookie=Add_Cookie_SessionID
                    $userSession=New_UserSession -Session $SessionCookie
                }
                $SessionID = $SessionCookie.value
                Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name SessionID -Value $SessionID -Force
                Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name SessionCookie -Value $SessionCookie -Force
                Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name userSession -Value $UserSession -Force
                if ($global:SessionObject.route.name -match '^(data|time|css|blank)$')
                {
                    $content = & $route.value
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name content -Value $content -Force
                }
                ELSE
                {
                    $content = Write_HTML -Content (AsHTML -InputObject (& $route.value))
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name content -Value $content -Force
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentLength64 = $buffer.Length
                if ($Buffer.Length -gt 100000)
                {
                    [byte[]]$GZipData = GzipResponse -Buffer $Buffer
                    Add-Member -InputObject $global:SessionObject -MemberType NoteProperty -name GZipData -Value $GZipData -Force
                    $global:SessionObject.response.OutputStream.WriteAsync($GZipData, 0, $GZipData.Length)
                    $AsynchronousOperationArray.add($global:SessionObject)
                }
                ELSE
                {
                    $global:SessionObject.response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
                    $AsynchronousOperationArray.add($global:SessionObject)
                }
            }
            if ($SessionID) {$SessionID,$UserSession}
            try{
                $response.OutputStream.Close()
                $response.Close()
                
            }catch{}
            
            $responseStatus = $global:SessionObject.response.StatusCode
            #get arround fields that are somtimes null
            $REP=$Context.Request.RemoteEndPoint | ?{$_} | %{$_.ToString()}
            $LEP=$Context.Request.LocalEndPoint | ?{$_} | %{$_.ToString()}
            Write-Host "$REP<$LEP $responseStatus"
            
            if ($I -gt 30000000) {return LastCall}
        }
    }