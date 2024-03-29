# Search for #FollowUp tags in code to find out what else needs work.

Add-Type -AssemblyName System.Web | out-null
if ($null -eq $global:Project_Root)
{
    $global:Project_Root = Split-Path (Split-Path (Split-Path ($MyInvocation.MyCommand.Definition,$MyInvocation.MyCommand.Module.Path | Where-object{$_ -match '^(\\\\|\w:)'}|Where-object{try{test-path $_}catch{}})))
}

    Function Write_log {
        param (
            $SessionObject=(Get-WebhostSessionObject),
            [string]$Message,
            $ErrorData,
            [string]$WarningText,
            [switch]$IncludeCallStack
        )
        if ($IncludeCallStack) {
            write-verbose -Message (Get-WebHostPSCallStackText -Skip 2 -First 2) -Verbose
        }
        Write-Verbose -Message ($Message + $ErrorData)
    }


    Function LastCall {
        write-host -ForegroundColor yellow -message $MyInvocation.MyCommand.Name
        if ($Global:IEWindow.Application)
        {
            $Global:IEWindow.Quit() 2>$null
            $Global:IEWindow = $Null
        }

        $Global:Context | Where-Object {$null -ne $_} | ForEach-Object {
            $_.Response.StatusCode = 404
            $_.Response.Close()
        }
        . {$Global:ListenerArray;$global:listener} |
        Where-Object {$null -ne $_} |
        Where-Object {$_.IsListening} |
        ForEach-Object {$_.GetContext()} | ForEach-Object {
            $ContextItem = $_
            try {$ContextItem.Response.StatusCode = 404} catch {}
            try {$ContextItem.Response.Close()} catch {}
        }

        [array]$DisposeofMe=$Global:ListenerArray | Where-Object{$_}
        if ($null -ne $global:listener) {$DisposeofMe+=$global:listener}
        $DisposeofMe | 
        Where-Object {
            $null -ne $_
        } | ForEach-Object {
            $Listener=$_
            try {$Listener.Prefixes.Clear()} catch {}
            try {$Listener.stop()} catch {}
            try {$Listener.Prefixes | Foreach-Object {$_} | Where-Object {$_} | Foreach-Object {$Listener.Prefixes.Remove($_)} 2>$null} catch {}
            try {$Listener.Close()} catch {}
            try {$Listener.Dispose()} catch {}
        }
        Remove-Variable listener                   -Scope global -ErrorAction silent -Force
        Remove-Variable ListenerArray              -Scope global -ErrorAction silent -Force
        Remove-Variable ListenerTable              -Scope global -ErrorAction silent -Force
        Remove-Variable listener_Anonymous         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_BasicAuth         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_WindowsIntegrated -Scope global -ErrorAction silent -Force
    }

    Function GetRandomUnusedTCPPort ([int]$Low = 982,[int]$High=984){
        Write-Verbose -message $MyInvocation.MyCommand.Name
        #Get a random TCP Port that is not used or within a narrow grouping.
        $Netstat = netstat -n -a
        $High++
        $low--
        $LocalPorts = &{$low;$Netstat | Foreach-Object {[int]($_ -split '\s\s*' -match ":" -split ":")[1]}; $High } |Sort-Object -Unique |Where-Object {($_ -le ($High)) -and ($_ -ge ($Low))}
        $LargestopenPortRange = $LocalPorts | Foreach-Object {
            $A = $_
            if ($B) {new-object psobject -Property @{Start=($B+1);Stop=($A-1);Gap=($A-1-$B)}}
            $B = $A
        } | Sort-Object gap -Descending | Select-Object -First 1
        $A=0;$B=0
        $LargestopenPortRange | Foreach-Object {
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

   
    Function GzipResponse {
        param (
            $Buffer,
            $SessionObject=(Get-WebhostSessionObject)
        )
        if ($Buffer.length -gt 0)
        {
            $MS  = New-Object system.io.MemoryStream 
            $Zip = New-Object System.IO.Compression.GZipStream  $ms, ([IO.Compression.CompressionMode]::Compress), $true
            $zip.Write($buffer, 0, $buffer.Length);
            $zip.Close()
            $ms.ToArray();
            $ms.Close()
            $SessionObject.context.response.AddHeader("Content-Encoding", "gzip");
        }
    }
     
    Function DecodeURLQuery {
        param (
            $SessionObject = (Get-WebhostSessionObject),
            $Context = $SessionObject.Context
        )
        $Query = $Context.Request.Url.Query
        $App_Params=@{}
        $Query -split '\?|\&' | Where-Object {$null -ne $_} | ForEach-Object {
            [string[]]$Split = $_ -split '\='
            $Name=[System.Web.HttpUtility]::UrlDecode($Split[0])  -replace '^\s*|\s*$'
            $Value=[System.Web.HttpUtility]::UrlDecode($Split[1]) -replace '^\s*|\s*$'
            if ($name -match 'json')    {try {$Value = $Value | ConvertFrom-Json} catch {}}
            if ($name -match 'json')    {try {$Value = $Value | ConvertFrom-Json} catch {}}
            if ($name -eq 'HttpMethod') {}
            elseif ($Split.count -eq 2) {$App_Params.add($Name,$Value)}
        }
        return $App_Params
    }

    function Launch_Application {
        param (
            $SessionObject = (Get-WebhostSessionObject),
            $Context = $SessionObject.Context,
            $User = $Context.user,
            $Path = ("$global:Project_Root\Routes\" + $Context.Request.Url.LocalPath), 
            $Query = $Context.Request.Url.Query
        )
        & $SessionObject.route
    }
    function Launch_Application_Old {
        param (
            $SessionObject = (Get-WebhostSessionObject),
            $Context = $SessionObject.Context,
            $User = $Context.user,
            $Path = "$global:Project_Root\wwwroot\", 
            $Query = $Context.Request.Url.Query
        )
        $DefaultDocs = 'index.html.ps1','index.html'

        # Turn the Query into parameters
        $QueryHT=@{}
        $Query -split '\?|\&' | Where-Object {$null -ne $_} | ForEach-Object {
            [string[]]$Split = $_ -split '\='
            $Name=[System.Web.HttpUtility]::UrlDecode($Split[0])  -replace '^\s*|\s*$'
            $Value=[System.Web.HttpUtility]::UrlDecode($Split[1]) -replace '^\s*|\s*$'
            if ($QueryHT.Contains($name)) {
                return .{
                    $Context.response.StatusCode = 422
                    $context.response.StatusDescription = "Unprocessable Entity - Duplicate Query Parameter"
                    "Duplicate Query Parameter"
                }
            }
            $QueryHT[$Name]=$Value
        }

        $PathObject = Get-Item -Path $Path -ErrorAction SilentlyContinue
        if ($Null -eq $PathObject) {
            Write-Verbose -Verbose -Message "PathObject is Null" 
            return Response_PageNotFound_404
        }
        elseif ($PathObject.PSIsContainer) {
            [string]$Path = ''
            $DefaultDocs|Where-Object{test-path "$Path\$_"}|Select-Object -First 1 | ForEach-Object {$Path="$Path\$_"}
            if ($Path -ne '') {$PathObject=Get-Item $Path}
            else {
                $PathObject=$null
                Write-Verbose -Verbose -Message "PathObject is Blank" 
                return Response_PageNotFound_404
            }
        }
        
        #Blank out ScriptParameters and conditionally fill that variable.
        $ScriptParameters         = if ($PathObject.name -match '\.ps1') {
                                        (get-command $Path).Parameters
                                        Write-Verbose -Verbose "Running: $(get-command $Path -ErrorAction SilentlyContinue |Select-Object * | Format-List|out-string)`n$($App_Params|Format-List)"
                                    }
                                    else {@{}}
        if ($ScriptParameters.Contains('GetApprovedArgs')) {
            
        }
        $ApprovedArgsHT = @{}
        # Check if the target script has the GetApprovedArgs parameter and obviously do not bother running the script with that parameter.
        # GetApprovedArgs is intended to return a list of parameters that can be called from the web.
        # #ToDo return a hashtable populated with scriptblocks from the destination program that custom parses and filters the web text.
        if ($ScriptParameters['GetApprovedArgs']) {
            & $Path -HttpMethod $SessionObject.WebRequest.HttpMethod -GetApprovedArgs | Where-Object {$_} | Foreach-Object {
                $ArgItem=$_
                switch ($ArgItem.GetType().name)
                {
                    'string' {
                        $ApprovedArgsHT.add($ArgItem,$True)
                    }
                    'hashtable' {
                        $ApprovedArgsHT=$ArgItem
                    }
                }
            }
        }
        
        #Block execution if unauthorized parameters are used.
        if ($App_Params.keys | Where-Object{-not ($Null -eq $ApprovedArgsHT[$_])}) {
            $SessionObject.context.response.statuscode=[System.Net.HttpStatusCode]::MethodNotAllowed
            #Todo #Followup make this output only for trusted clients or localhost.
            return "Unauthorized parameter.  Authorized parameters are $($ApprovedArgsHT.keys -join ',')."
        }
        
        if ($ScriptParameters['HttpMethod']) {$AppParams.add('HttpMethod',$SessionObject.WebRequest.HttpMethod)}
        if ($ScriptParameters['InputStreamText']) {$AppParams.add('InputStreamText',$SessionObject.InputStreamText)}
        $AppParams.keys|Where-Object{-not $ScriptParameters.Contains($_)}
        $SessionObject.InputStreamText
        return (& $Path @App_Params)
    }

    Function Get-WebHostPSCallStackText ([int]$Skip=1,$First=0,$SkipLast=0) {
        $Params = @{}
        if ($Skip -ne 0    ) {$Params.add('Skip'    ,$Skip)}
        if ($First -ne 0)    {$Params.add('First'   ,$First)}
        if ($SkipLast -ne 0) {$Params.add('SkipLast',$SkipLast)}
        ((Get-PSCallStack|Select-Object @Params|Format-List|out-string) -replace '\s*\n\s*\n(\s*\n)*',"`n-------------`n" -split '\s*\n'|Where-Object {$_} |ForEach-Object{"`n|`t$_"}) -join ''
    }

    Function html {
        param (
            $TagName,
            $InnerHTML,
            $TagData,
            $NoTerminatingTag
        )
        if ($null -eq $TagName) {write-warning "html function ran with no -TagName$(Get-WebHostPSCallStackText -Skip 2 -First 1)"}
        if ($TagData) {if ($TagData.GetType().Name -eq 'ScriptBlock') {[string]$TagDataString=. $TagData}}
        if ($TagData) {if ($TagData.GetType().Name -eq 'hashtable')   {
            [string]$TagDataString=($Tagdata.keys|Where-Object{$null -ne $_}|ForEach-Object{[System.Web.HttpUtility]::HtmlEncode($_)+'="'+[System.Web.HttpUtility]::HtmlEncode($TagData[$_])+'"'}) -join " "
        }}
        else {[string]$TagDataString = $TagData}
        if ($innerHTML) {
            $innerHTML
        }
        '<'+$TagName+' ' +$TagDataString+(.{if($NoTerminatingTag){'/'}})+'>'+$innerHTMLString+(.{if (-not $NoTerminatingTag){'</'+$TagName+'>'}})
    }

    new-Alias AsHTML -Value Convertto-DOM

    Function AsHTML_old {
        param(
            [array]$InputObject
        )
        begin {
            Function FlushTableData {
                $Output+=($TableData | Where-Object | ConvertTo-Html -Fragment) + '<p />'
                $TableData.Clear()
            }
            Function ProcessInputObject  {
                begin {
                    [string]$Output=''
                    [array]$TableData=@()
                    [string]$ObjectType_Previous=''
                }
                process {
                    if ($null -eq $InputObjectItem) {$Output+=_P -innerHTML ([System.Web.HttpUtility]::HtmlEncode([char][int]0))}
                    [string]$ObjectType=$InputObjectItem.gettype().name
                    if($ObjectType_Previous -ne $ObjectType) {
                        . FlushTableData
                    }
                    if ($ObjectType -eq 'string') {
                        . FlushTableData
                        $Output+=(
                            $Output += _p -innerHTML (
                                [System.Web.HttpUtility]::HtmlEncode(
                                    $InputObject
                                )
                            )
                        )
                    }
                    elseif ($ObjectType -eq 'string[]') {
                        . FlushTableData
                        $Output+=(
                            $InputObject | ForEach-Object {
                                $Output += _ul -innerHTML (
                                    _li -innerHTML (
                                        [System.Web.HttpUtility]::HtmlEncode(
                                            $_
                                        )
                                    )
                                )
                            }
                        )
                    }
                    elseif ($ObjectType -eq 'securestring') {
                        '[securestring]'
                    }
                    elseif ($ObjectType -like '^int\[{0,1}\]{0,1}') {
                        . FlushTableData
                        $Output+=(
                            $InputObject | ForEach-Object {
                                $Output += _p -innerHTML ([System.Web.HttpUtility]::HtmlEncode(
                                    $_
                                ))
                            }
                        )
                    }
                    else{
                        $ParametersHT = @{}
                        $InputObjectItem.psobject.$Parameters | ForEach-Object {$ParametersHT.add($_.Name,$_)}
                        [array]$Overlap = $ParametersHT.Keys | Where-Object {$ParametersHT_Previous.contains($_)}
                        if (
                            ($Overlap.count -gt 1) -and
                            ($Overlap -gt ($ParametersHT.count / 10))
                        ) 
                        {
                            $TableData+=$InputObject
                        }
                        else {
                            . FlushTableData
                        }
                        $ParametersHT_Previous = $ParametersHT
                    }
                    $ObjectType_Previous=$ObjectType
                }
                end {
                    . FlushTableData
                    return $Output
                }
            }
            foreach ($InputObjectItem in $InputObject) {
            }
            

            function ProcessInputObjectOLD {
                param ($InputObject)
                begin {$InputObject | . ProcessInputObject}
                process {
                    [string]$ObjectType = $InputObject.gettype().name
                    if ($ObjectType -ne $ObjectType_Old) {[bool]$NewType = $True} ELSE {[bool]$NewType = $False}
                    
                    if ($ObjectType -eq "string") 
                    {
                        Complete_Table -AppendTableBuffer $AppendTableBuffer `
                            -AppendTableBufferProps $AppendTableBufferProps `
                            -AppendTableBufferPropsHT $AppendTableBufferPropsHT `
                            -Horizontal:([bool]($AppendTableBufferProps.count -gt $AppendTableBuffer.count))
                        $InputObject
                    }
                    ELSE
                    {
                        IF ($InputObject.HTMLOutputFormat -eq "HTABLE")
                        {
                            $InputObject | Select-Object -ExcludeProperty HTMLOutputFormat | Write_HTable
                        }
                        IF ($InputObject.HTMLOutputFormat -eq "Tag")
                        {
                            write_tag -Tag $InputObject.tag -TagData $InputObject.TagData -Content $InputObject.Content
                        }
                        ELSE
                        {
                            switch -regex ($ObjectType)
                            {
                                "^string|^int|^uint" {
                                    Complete_Table -AppendTableBuffer $AppendTableBuffer `
                                        -AppendTableBufferProps $AppendTableBufferProps `
                                        -AppendTableBufferPropsHT $AppendTableBufferPropsHT `
                                        -Horizontal:([bool]($AppendTableBufferProps.count -gt $AppendTableBuffer.count))
                                    '<P data_type="String">' + $InputObject + '</P>'
                                }
                                default {
                                    . Append_Table -InputObject $InputObject 
                                }
                            }
                        }
                    }
                    $ObjectType_Old = $ObjectType
                }
                end {
                    if ($AppendTableBufferProps) {
                        if ($AppendTableBufferProps.count ) {
                            Complete_Table -AppendTableBuffer $AppendTableBuffer `
                                -AppendTableBufferProps $AppendTableBufferProps `
                                -AppendTableBufferPropsHT $AppendTableBufferPropsHT `
                                -Horizontal:([bool]($AppendTableBufferProps.count -gt $AppendTableBuffer.count))
                        }
                    }
                }
            }
        }
        process {
            if ($_)
            {
                . ProcessInputObject -InputObject $_
            }
        }
        end {
            if ($null -ne $AppendTableBuffer) { 
                if ($AppendTableBuffer.count -ne 0) {
                    Complete_Table -AppendTableBuffer $AppendTableBuffer `
                        -AppendTableBufferProps $AppendTableBufferProps `
                        -AppendTableBufferPropsHT $AppendTableBufferPropsHT `
                        -Horizontal:([bool]($AppendTableBufferProps.count -gt $AppendTableBuffer.count))
                }
            }
        }   
    }
    
    Function Write_HTable {
        Param (
            $Inputobject,
            [string[]]$Property,
            #$RowTitleProperty,
            [string]$TagData = "border=1 style=""font-size:12px;background-color:white;color:black;""",
            [string]$KeyName
        )

        begin {
            $HTableData=New-Object System.Collections.ArrayList
            if ($Property.count -eq 0)
            {
                $Inputobject | Where-Object {$_} | Foreach-Object {$HTableData.add($_)} > $null
            }
            ELSE
            {
                $Inputobject | Select-Object $Property | Where-Object {$_} | Foreach-Object {$HTableData.add($_)} > $null
            }
        }
        process{
            if ($Property.count -eq 0)
            {
                if ($_ -ne $null) {$HTableData.add($_) > $null}
            }
            ELSE
            {
                if ($_ -ne $null) {$HTableData.add(($_ | Select-Object $Property)) > $null}
            }
        }
        end {
            if ($HTableData.count -gt 0)
            {
                [scriptblock]$HTMLEncodeSB = {$_ -replace '\<','&lt;' -replace '\>','&gt;' -replace '"','&quot;' -replace '''','&#39;' -replace '\s\s',' &nbsp'}
                if     ((& {try {[System.Web.HttpUtility]::HtmlEncode('<')} catch{}})) {$HTMLEncodeSB={[System.Web.HttpUtility]::HtmlEncode($_)}} #HttpUtility
                elseif ((& {try {[System.Net.WebUtility]::HtmlEncode('<')}  catch{}})) {$HTMLEncodeSB={[System.Net.WebUtility]::HtmlEncode($_) }} #WebUtility
                $PropsHT = @{}; 
                if ($KeyName -eq '')
                {
                    [string]$PropMode='ItemCount'
                }
                ELSE
                {
                    [string]$PropMode='Named'
                    $TestHT=@{}
                    [int32]$TI=0
                    $HTableDataProps=$HTableData|Foreach-Object {$_.($KeyName)}| Where-Object {$null -eq $TestHT[$_]}|Foreach-Object {$TestHT.add($_,$True);$TI++}
                    if ($HTableDataProps.count -gt $TI) {$PropMode='ItemCount'}
                    #Release Memory
                    $TestHT.Clear()
                }
                $Props = $HTableData |Where-Object {$_}|Where-Object {$_.psobject}|Foreach-Object {
                    $_.psobject.Properties | Select-Object -ExpandProperty Name
                } | Where-Object {$null -eq $PropsHT[$_]} | Foreach-Object {$PropsHT.add($_,$True);$_}
                $I=0
                _table -innerHTML (.{
                    _tr -innerHTML (.{
                        _th -innerHTML _Properties
                        if ($PropMode -eq 'Named')
                        {
                            (0..($HTableData.count -1))|Foreach-Object {
                                (_td -innerHTML $HTableData[$_].($KeyName)) + "`n"
                            }
                        }
                        ELSE
                        {
                            (0..($HTableData.count -1))|Foreach-Object {
                                (_td -innerHTML "Item $_") + "`n"
                            }
                        }
                    })
                    $Props | ForEach-Object {
                        $PropItem = $_
                        _tr -innerHTML (.{
                            _th -innerHTML $PropItem
                            $HTableData | Foreach-Object {
                                [string]$V=($_.($PropItem) -split '\n' | Where-Object {$_} | Foreach-Object $HTMLEncodeSB) -join "<BR>`n"
                                (_td -innerHTML $V) + "`n"
                            }
                        })
                        $I++
                    }
                })
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
            
            ($URL + $Args)|Where-Object {$_ -match "https*:\/\/"}  | Foreach-Object {
                $wc.DownloadString("$_")|out-null
            }
            Start-Sleep $Interval
        }
    }
    
    function IsLocalRequest {
        #$Query = $global:Context.Request.Url
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
        $Global:Dispose | Where-Object {$_.DisposeAfter} | Where-Object {$_.DisposeAfter -le $now} | Foreach-Object {
            $_.object.dispose()
            & $_.AfterDisposalAction
        }
        $Global:Dispose = $Global:Dispose | Where-Object {$_.DisposeAfter -gt $now}
    }

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

    Function Add_Cookie {
        param (
            $SessionObject=(Get-WebhostSessionObject),
            $Context=$SessionObject.context,
            [string]$Name,
            $Value,
            $Comment,
            $CommentUri,
            [bool]$HttpOnly=$True,
            $Discard,
            $Version,
            $TimeStamp,
            $Domain,
            $Expires = ((get-date).AddMinutes(600).ToUniversalTime().ToString() + ' GMT'),
            [bool]$Secure,
            $Port,
            $Path,
            [switch]$Passthrough
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
        $CookieFromContext=$Context | 
            Select-Object -ExpandProperty request | 
            Select-Object -ExpandProperty Cookies | 
            Where-Object {$_ -ne $null} | 
            Foreach-Object {$_[$Cookie.Name]}
        if ($null -ne $CookieFromContext)
        {
            write-host ($Context.request | out-string )
            write-host ($Context.request.TransportContext | out-string )
            write-host ($Context.request.InputStream | out-string )
            write-host "AppendCookie: $Cookie" -fore yellow
            #$Context.Response.AppendCookie($Cookie)
            $Context.Response.addheader('Set-Cookie',$Cookie)
        }
        ELSE
        {
            write-host "SetCookie: $Cookie" -fore yellow
            try {$Context.Response.Cookies.Add($Cookie)} catch {
                $_
                try {$Context.Response.SetCookie($Cookie)} 
                catch {
                    $_
                }
                try {
                    $Context | Where-Object {$_ -ne $null} | 
                        Select-Object -ExpandProperty Response | Where-Object {$_ -ne $null}|
                        Select-Object -ExpandProperty headers| Where-Object {$_ -ne $null} | 
                        Foreach-Object {$_.add('Set-Cookie',$Cookie)}
                }
                catch {$_}
            }
            
        }
        if ($Passthrough) {$Cookie}
    }

    Function Add_Cookie_SessionID {
        param(
            $SessionObject=(Get-WebhostSessionObject),
            $Context=$SessionObject.Context
        )
        $ExistingCookie = $Context.Request.Cookies['SessionID']
        if (-not $ExistingCookie)
        {
            #ToDo Get rid of static reference.
            Add_Cookie -Passthrough -Name SessionID `
            -Domain *.skarke.net,skarke.net,localhost `
            -Value (get-date).ToFileTimeUtc() `
            -Expires  ((get-date).AddSeconds(36000).ToUniversalTime().ToString() + ' GMT') `
        }
    }

    Function Get_Cookie_SessionID {
        param (
            $SessionObject=(Get-WebhostSessionObject),
            $Context=$SessionObject.context
        )
        if ($null -eq $Context) {
            return (write-error -Message "Null contect passed to ")
        }
        $FQDN = $Context.request.UserHostName -replace ':\d\d*$'
        $SessionIDCookieName='PSWeb_'+$FQDN
        $SessionID=$Context.Request.Cookies[$SessionIDCookieName].value
        if ($null -eq $SessionID) {
            $NewCookie_SessionID = [System.Net.Cookie]::new()
            $NewCookie_SessionID.Name = $SessionIDCookieName
            $NewCookie_SessionID.value = Generate-JWT -Algorithm HS256  -payload (
                New-JWTClaim -Subject 'anonymous' -ValidforSeconds 3600 -Issuer $fqdn
            ) -
            $NewCookie_SessionID.HttpOnly = $true
            $NewCookie_SessionID.Secure = $true
            $NewCookie_SessionID.Domain = "*.$FQDN"
            $NewCookie_SessionID.Expires = (get-date).AddSeconds(3600)
            $Context.Response.Cookies.add($NewCookie_SessionID)
            $SessionID=$NewCookie_SessionID
        }
        $SessionID
    }

    Function Get_UserSession ($SessionObject=(Get-WebhostSessionObject),$SessionCookie=$SessionObject.SessionCookie) {
        $SessionID = $SessionCookie.Value
        if ($null -ne $SessionID)
        {
            $SessionItemIndex=$Global:UserSessionTable[$SessionID]
        }
        ELSE
        {
            $SessionItemIndex=$null
        }
        $SessionItem = $Null
        if ($null -ne $SessionItemIndex) {$SessionItem = $Global:UserSessionArray[$SessionItemIndex]}
        if ($null -eq $SessionItem)
        {
            New_UserSession -SessionObject $SessionObject -SessionCookie $SessionCookie
        }
        ELSE
        {
            $SessionItem
        }
    }


    if ($null -eq $Global:UserSessionTable) {$Global:UserSessionTable = @{}}
    if ($null -eq $Global:UserSessionArray) {$Global:UserSessionArray = new-object System.Collections.ArrayList}

    Function New_UserSession {
        [cmdletbinding()]
        param (
            $SessionObject=(Get-WebhostSessionObject),
            $SessionCookie=$SessionObject.SessionCookie,
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
        if ($null -eq $SessionIndex) 
        {$SessionItem=$null}
        ELSE
        {
            $SessionItem = $Global:UserSessionArray[$SessionIndex]
        }
        if ($SessionIndex -and -not $force)
        {
            Write-warning -Message 'New_UserSession was used, but $Global:UserSessionTable contains an existing session.' 
        }
        ELSEIF ($SessionIndex -and $Force)
        {
            Write-Warning -Message "resetting session $SessionIndex - `n$($session)"
            $Global:UserSessionArray[$SessionIndex].PrivateSessions |Where-Object {$_} |Foreach-Object {$_.dispose()}
            $NewuserSession=New_UserSessionObject -SessionCookie $SessionCookie  

            $Global:UserSessionArray[$SessionIndex]=$NewuserSession
        }
        ELSEIF ($null -ne $SessionIndex)
        {
            $SessionItem
        }
        ELSE
        {
            $NewuserSession=New_UserSessionObject -SessionCookie $SessionCookie 
            $Global:UserSessionTable.add($SessionID,$Global:UserSessionArray.add($NewuserSession))
            return $NewuserSession
        }
    }

    #FollowUP
    Function New_UserSessionObject {
    param (
        [System.Net.Cookie]$SessionCookie,
        [string]$UserAgent = $Global:Context.Request.UserAgent,
        [psobject[]]$GeoIPData = (
            . {
                if ($null -ne $Context.Request.RemoteEndPoint) 
                {
                    #Get-GeoIP -IP $Context.Request.RemoteEndPoint.ToString()
                }
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
        [psobject]$WebUserProfile
    )
        $Object=New-Object psobject -Property ([ordered]@{
            SessionCookie=[System.Net.Cookie]$SessionCookie
            UserAgent=[string]$UserAgent
            UserAgentHistory=[System.Collections.ArrayList]::new()
            GeoIPData=[psobject[]]$GeoIPData
            CredentialSet=$CredentialSet
            Password=[securestring]$Password
            WebUserProfile=[psobject]$WebUserProfile
            PrivateSessions=@()
            Jobs=@()
        })
        if ($null -eq $UserSessionObject_UserAgentHistory_Update)
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
        if ($null -eq $Global:ResponseArray_Closed) {$Global:ResponseArray_Closed = New-Object System.Collections.ArrayList}
        [int]$I=0
        [int[]]$Cleanup=@()
        $AsynchronousOperationArray | Foreach-Object {
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
                    $Global:ResponseArray_Closed.add($AsynchronousOperationCleanupItem) 2> $null
                    if ($Global:ResponseArray_Closed.count -gt 10) 
                    {
                        (0..($Global:ResponseArray_Closed.count-10))|Foreach-Object {
                            $Global:responseArray.RemoveAt(0)
                        }
                    }
                    $Cleanup += $I
                }
            }
            $I++
        }
        if ($Cleanup.count)
        {
            $Cleanup[-1..(-$cleanup.Count)]  | Foreach-Object {$Script:AsynchronousOperationArray.RemoveAt($_) > $Null}
        }
        if ($I -gt 1) {write-host AsynchronousOperationArray count is $I}
    }

    Function CleanupResponseArray {
        if ($null -eq $Global:ResponseArray_Closed) {$Global:ResponseArray_Closed = New-Object System.Collections.ArrayList}
        for ($RI=0;$RI -lt ($responseArray.count - 10);$RI++)
        {
            #write-progress -Activity CleanupResponseArray -PercentComplete ((100 / $responseArray.count) * $RI)
            $RAItem = $Global:responseArray.item($RI)
            #$RAItem.OutputStream.FlushAsync() 2> $null
            if ($null -ne $RAItem.OutputStream)
            {
                 try{$RAItem.OutputStream.Close()}catch{}
                 try{$RAItem.response.Close()}catch{}
                 try{$RAItem.OutputStream.dispose()}catch{}
            }
            if ($null -ne $RAItem)
            {
                try {
                    try{$RAItem.Close()}catch{}
                    try{$RAItem.dispose()}catch{}
                    $Global:ResponseArray_Closed.add($Global:responseArray[$RI]) 2> $null
                    if ($Global:ResponseArray_Closed.count -gt 10) 
                    {
                        (0..($Global:ResponseArray_Closed.count-10))|Foreach-Object {
                            $Global:responseArray.RemoveAt(0)
                        }
                    }
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
            $AsynchronousOperationArray=$Global:AsynchronousOperationArray
        )
        if ($null -eq $Global:AsynchronousOperationArray) {$Global:AsynchronousOperationArray = new-object system.collections.arraylist}
        CleanupAsynchWriteOperations
        ProcessContext
    }

    Function Response_Outputstream_Write {
        param(
            $SessionObject=(Get-WebhostSessionObject),
            $Content,
            $ContentType,
            [switch]$UseGzip
        )
        [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $Context = $SessionObject.Context
        if ($UseGzip -and ($buffer.count -ne 0))
        {
            [byte[]]$GZip = GzipResponse -Buffer $buffer
            $Buffer=$GZip
        }
        $Context.response.ContentLength64 = $buffer.Length
        $Context.response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Context.response.OutputStream.Write([byte]$null,0,0)
        #$AsynchronousOperationArray.add($SessionObject)
        try{$Context.response.OutputStream.close()}catch{}
        try{$Context.response.close()}catch{}
        return            
    }

    Function Response_Outputstream_WriteAsync {
        param (
            $SessionObject=(Get-WebhostSessionObject),
            $Content,
            [string]$ContentType,
            [switch]$UseGzip
        )
        if($null -eq $Content) {
            write-verbose -Message "Function Response_Outputstream_WriteAsync has been passed an empty context`n$(
                Get-WebHostPSCallStackText -Skip 2 -First 1
            )" -Verbose
            $SessionObject.context.response.close()
            $SessionObject.context.response.dispose()
            return
        }
        elseif($Content[0].GetType().name -eq 'Byte')
        {
            [byte[]]$buffer = $Content
        }
        else
        {
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        }
        if ($UseGzip -and ($buffer.count -ne 0))
        {
            [byte[]]$GZip = GzipResponse -Buffer $buffer
            $Buffer=$GZip
        }
        $SessionObject.context.response.ContentLength64 = $buffer.Length
        $SessionObject.context.response.ContentType = $ContentType
        $WriteAsyncHandle=$SessionObject.context.response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
        Add-Member -InputObject $SessionObject -MemberType NoteProperty -name WriteAsyncHandle -Value $WriteAsyncHandle -Force
        $Global:AsynchronousOperationArray.add($SessionObject)
    }

    Function Get-WebhostNewSessionObects {
        Get-WebHostListener | Where-Object {$_.islistening} | ForEach-Object {
            $Listener = $_
            new-object psobject -Property @{
                Context=$Listener.getcontext()
                isdisposed=[bool]$false
            }                    
        }
    }

    Function Get-WebhostSessionObject {
        try {
            ((0..5)| ForEach-Object { try{Get-Variable -NAME SessionObject -Scope $_ -ErrorAction SilentlyContinue}catch{}} | Select-Object -First 1).value
        }
        catch {
            write-warning "Get-WebhostSessionObject `$SessionOject not found!"
        }
    }

    Function ProcessContext {
        Get-WebhostNewSessionObects | Where-Object {$_} | ForEach-Object {
            #Add PSRunspace handoff here.
            ProcessContextItem -SessionObject $_
        }
    }

    Function ProcessContextItem {
        param (
            $SessionObject=(Get-WebhostSessionObject),
            $Context = $SessionObject.context
        )
        IF ($Context.Request)
        {
            if ($Context.Request.Url.LocalPath -like '/blank*')
            {
                Response_Outputstream_Write -SessionObject $SessionObject -Content ''
            }
            ELSEif (-not [bool]$Context.request.UserAgent)
            {
                Response_Outputstream_Write -SessionObject $SessionObject -Content 'UP'
            }
            else{
                # Non-blank UserAgent
                ''>$null
            }
            write-verbose -Verbose "UserAgent: $($Context.request.UserAgent)"
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name context -Value $Context -Force
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name requestUrl -Value $Context.Request.Url -Force
            #Add-Member -InputObject $SessionObject -MemberType NoteProperty -name response -Value $Context.Response -Force
            
            if ($SessionObject.isdisposed) {
                return 
            }
            elseif ($SessionObject.context.response.isdisposed) {
                return
            }
            try {$SessionObject.context.response.KeepAlive = $True}
            catch {
                $ErrorVal = $_
                if ($ErrorVal.Exception.Message -match 'Cannot access a disposed object')
                {
                    add-member -InputObject $SessionObject -Force -MemberType NoteProperty -Name isdisposed -Value $True
                }
                return
            }
            #$SessionObject.context.response.SendChunked = $True
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name WebRequest -Value $Context.Request -Force
            $WebRequest = $Context.Request
            

            $Method = $SessionObject.WebRequest.HttpMethod
            Write-Verbose -Message "Method: $Method $($SessionObject.requestUrl.LocalPath)" -Verbose
            switch ($Method)
            {
                'post'
                {
                    
                    $Reader = new-object System.IO.StreamReader $WebRequest.InputStream,$WebRequest.ContentEncoding
                    $ReaderString = $Reader.ReadToEnd() -split '\&'
                    $InputStreamText = $ReaderString|Where-Object {$_}|Foreach-Object {[system.web.httputility]::UrlDecode($_)}
                    break
                }
                'get'
                {
                    $Reader = new-object System.IO.StreamReader $WebRequest.InputStream,$WebRequest.ContentEncoding
                    $ReaderString = $Reader.ReadToEnd() -split '\&'
                    $InputStreamText = $ReaderString|Where-Object {$_}|Foreach-Object {[system.web.httputility]::UrlDecode($_)}
                    break
                }
                'options' {
                    $SessionObject.context.response.StatusCode = 501
                    $SessionObject.context.response.OutputStream.Close()
                    $SessionObject.context.response.close()
                    break
                }
                'put' {
                    $Reader = new-object System.IO.StreamReader $WebRequest.InputStream,$WebRequest.ContentEncoding
                    $ReaderString = $Reader.ReadToEnd() -split '\&'
                    $InputStreamText = $ReaderString|Where-Object {$_}|Foreach-Object {[system.web.httputility]::UrlDecode($_)}
                    break
                }
                'delete' {
                    $Reader = new-object System.IO.StreamReader $WebRequest.InputStream,$WebRequest.ContentEncoding
                    $ReaderString = $Reader.ReadToEnd() -split '\&'
                    $InputStreamText = $ReaderString|Where-Object {$_}|Foreach-Object {[system.web.httputility]::UrlDecode($_)}
                    break
                }
                default
                {
                    write-warning -Message "SessionObject.WebRequest.HttpMethod specifies a unsupported method '$($SessionObject.WebRequest.HttpMethod)'.  Closing connection.`n$(
                
                        $SessionObject.WebRequest.HttpMethod.psobject.properties | ForEach-Object {
                            (
                            $_ | Format-List | 
                            out-string
                            )  -split '\n' | Where-Object {$_ -notmatch '^\s*$'} | ForEach-Object{"`n|`t$_"}
                            "`n|"
                        }
                    )"
                    $SessionObject.context.response.StatusCode = 405
                    $SessionObject.context.response.close()
                    $SessionObject.context.response.dispose()
                    return
                    $ReaderString = $null
                    $InputStreamText = $null
                }
            }
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name Reader -Value $Reader -Force
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name ReaderString -Value $ReaderString -Force
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name InputStreamText -Value $InputStreamText -Force
            remove-variable Reader
            remove-variable ReaderString
            remove-variable InputStreamText

            $localPath = $SessionObject.requestUrl.LocalPath
            Write-Verbose -Message "localPath: $localPath" -Verbose

            $localPath | Where-Object {$_}
            [string]$LocPath = [Web.HttpUtility]::UrlDecode($localPath) -replace '^//*' 
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name LocPath -Value $LocPath -Force
        
            $Global:RoutePath = "$Global:Project_root\Routes\$LocPath\Method_$Method.ps1" -replace '\\','/' -replace '//*','/'
            $WWWRootPath = "$Global:Project_root\wwwroot\$LocPath" -replace '\\','/' -replace '//*','/'
            [array]$LocPathSplit = ($LocPath -split '/?')[0] -split '\/|\\'
            if (test-path $Global:RoutePath) {
                [string]$Global:Route = $Global:RoutePath
            }
            elseif (
                ($LocPathSplit[0] -eq 'wwwroot') -and
                ($Method -eq 'GET')
            ) {
                [scriptblock]$Global:Route = {
                    Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 300;
                    $Data = get-content (
                        try {$Using:WWWRootPath} catch {$WWWRootPath}
                    )
                    return $Data
                }
            }
            
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name route -Value $Global:Route -Force
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name SessionCookie -Value (Get_Cookie_SessionID -SessionObject $SessionObject) -Force
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name UserSession   -Value (Get_UserSession -SessionObject $SessionObject) -Force
            if (-not $SessionObject.SessionCookie) {
                $SessionObject.SessionCookie=Add_Cookie_SessionID
                Add-Member -InputObject $SessionObject -MemberType NoteProperty -name UserSession   -Value (New_UserSession -SessionCookie $SessionObject.SessionCookie) -Force
            }
            Add-Member -InputObject $SessionObject -MemberType NoteProperty -name SessionID -Value $SessionObject.SessionCookie.value -Force

            if ($null -eq $Global:Route)
            {
                $SessionObject.context.response.StatusCode = 404
                $SessionObject.context.response.OutputStream.Close()
                $SessionObject.context.response.close()
            }
            else {
                if (test-path $Global:Route) {$Global:Mimetypes[($Global:Route -replace '.*?(\.\w\w*)$','$1')]}
                $Content = & $Global:Route 
                [bool]$Compress=$False
                Response_Outputstream_WriteAsync -SessionObject $SessionObject -ContentType $MimeTypeItem -Content $Content -UseGzip:$Compress
            }
            $SessionObject.context.response.close()
            $SessionObject.context.response.dispose()
            if ($SessionID) {$SessionID,$UserSession}
            $responseStatus = $SessionObject.context.response.StatusCode
            #get arround fields that are somtimes null
            $REP=$Context.Request.RemoteEndPoint | Where-Object {$_} | Foreach-Object {$_.ToString()}
            $LEP=$Context.Request.LocalEndPoint | Where-Object {$_} | Foreach-Object {$_.ToString()}
            Write-Host "$REP<$LEP $responseStatus $LocPath"
            if ($I -gt 30000000) {return LastCall}
        }
    }

