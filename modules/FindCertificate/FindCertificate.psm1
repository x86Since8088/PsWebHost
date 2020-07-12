new-alias -Force FindCertificate_WS Find-ValidCertificate_WS
Function Find-ValidCertificate_WS {
    param  ([string]$URLItem) 
    Get-FunctionReferenceCheck_WS
    if ('' -eq $URLItem) {return}
    if ($URLItem -notmatch 'https') {return}
    $date = get-date
    $HostName = $URLItem -replace '^\w\w*://' -replace ':.*' -replace '/.*'
    $CertificatesReport = @()
    foreach ($Cert in (Get-ChildItem Cert:\LocalMachine\my |Sort-Object NotAfter -Descending)) {
        $CertHost = $cert.Subject -replace '^CN=' -replace ',.*'
        $CertificateEvaluation = Validate-Certificate_WS -Certificate $Cert
        $Score=0
        if ($CertificateEvaluation.HasPrivateKey                ) {$Score=2}
        if ($CertificateEvaluation.CertificateIsValid           ) {$Score*=2}
        if ($CertificateEvaluation.ChainStatus -eq 'good'       ) {$Score*=2}
        if ($CertificateEvaluation.DnsNameList|
            ?{$HostName -like "$_*"}                            ) {$Score*=2}
        if ($CertificateEvaluation.DnsNameList|
            ?{$_ -like "$HostName*"}                            ) {$Score*=2}
        if ($CertificateEvaluation.EnhancedKeyUsageList -match 
            'server authentication'                             ) {$Score*=2}
        if ($Cert.NotAfter  -lt $date                           ) {$Score/=2}
        $CertificatesReport += $CertificateEvaluation | Select @{n='Score';e={$Score}},@{n='Cert';e={$Cert}},* -ErrorAction SilentlyContinue
    }
    $Ordered=$CertificatesReport | Sort Score -Descending 
    $SelectedCert = $Ordered | select -First 1
    $Ordered | select -Skip 1 | ForEach-Object {
        Log -data @{
            URLItem=$URLItem
            Cert=$SelectedCert
        } -Message 'Certificate Skipped'
    }
    Log -data @{
        URLItem=$URLItem
        Cert=$SelectedCert
    } -Message 'Match selected'
    $SelectedCert.Cert

}

Function Validate-Certificate_WS {
<#
.Synopsys
    the code for this function was moved from Get-PortCertificate by Eddie Skarke for code reuse.
#>    
    param (
        [string]$ComputerNameFQDN,
        $Certificate
    )
    Write-Verbose "[$($ComputerNameFQDN)] Certificate found!  Building certificate chain information and object data."

    #build our certificate chain object
    $chain = [Security.Cryptography.X509Certificates.X509Chain]::create()
    $isValid = $chain.Build($certificate)

    #get certificate subject names from our certificate extensions
    $validnames = @()
    try{[array]$validnames += @(($certificate.Extensions | ? {$_.Oid.Value -eq "2.5.29.17"}).Format($true).split("`n") | ? {$_} | % {$_.split("=")[1].trim()})}catch{}
    try{[array]$validnames += @($certificate.subject.split(",")[0].split("=")[1].trim())}catch{}

    #validate the target name
    for($i=0;$i -le $validnames.count - 1;$i++){
        if ($validnames[$i] -match '^\*'){
            $wildcard = $validnames[$i] -replace '^\*\.'
            if($ComputerNameFQDN -match "$wildcard$"){
                $TargetNameIsValid = $true
                break
            }
            $TargetNameIsValid = $false
        }
        else{
            if($validnames[$i] -eq $ComputerNameFQDN){
                $TargetNameIsValid = $true
                break
            }
            $TargetNameIsValid = $false
        }
    }

    #create custom object to later convert to PSobject (required in order to use the custom type name's default display properties)
    $customized = $certificate | select *,
        @{n="ExtensionData";e={$_.Extensions | % {@{$_.oid.friendlyname.trim()=$_.format($true).trim()}}}},
        @{n="ResponseUri";e={if ($Response.ResponseUri){$Response.ResponseUri}else{$false}}},
        @{n="ExpiresIn";e={if((get-date) -gt $_.NotAfter){"Certificate has expired!"}else{$timespan = New-TimeSpan -end $_.notafter;"{0} Days - {1} Hours - {2} Minutes" -f $timespan.days,$timespan.hours,$timespan.minutes}}},
        @{n="TargetName";e={$ComputerNameFQDN}},
        @{n="CertificateValidNames";e={$validnames}},
        @{n="ChainPath";e={$count=0;$chaincerts = @($chain.ChainElements.certificate.subject);$($chaincerts[($chaincerts.length -1) .. 0] | % {"{0,$(5+$count)}{1}" -f "---",$_;$count+=3}) -join "`n"}},
        @{n="ChainCertificates";e={@{"Certificates"=$chain.ChainElements.certificate}}},
        @{n="ChainStatus";e={if($isvalid -and !$_.chainstatus){"Good"}else{$chain.chainstatus.Status}}},
        @{n="ChainStatusDetails";e={if($isvalid -and !$_.chainstatus){"The certificate chain is valid."}else{$chain.chainstatus.StatusInformation.trim()}}},
        @{n="CertificateIsValid";e={$isValid}},
        @{n="TargetNameIsValid";e={$TargetNameIsValid}},
        @{n="TargetNameStatus";e={if($TargetNameIsValid){"Good"}else{"Invalid"}}},
        @{n="TargetNameStatusDetails";e={if($TargetNameIsValid){"The target name appears to be valid: $ComputerNameFQDN"}else{"TargetName $ComputerNameFQDN does not match any certificate subject name."}}} 
            
                 
    #get object properties for our PSObject
    $objecthash = [Ordered]@{}
    ($customized | Get-Member -MemberType Properties).name | % {$objecthash+=@{$_=$customized.$_}}
            
    #create the PSObject
    $psobject = New-Object psobject -Property $objecthash

    #add the custom type name to the PSObject
    $psobject.PSObject.TypeNames.Insert(0,'Get.PortCertificate')         

    #return the object
    $psobject

}

Function Get-PortCertificate_WS {

<#

.SYNOPSIS
    Returns certificate information from a listening TLS/SSL service port.

.DESCRIPTION
    Gets the associated certificate from a TLS/SSL application service port.

.PARAMETER  Computername
    Hostname or IP address of the target system (Default: localhost).  The function uses the supplied computername to validate with the certificate's subject name(s).

.PARAMETER  Port
    Port to retrieve SSL certificate (Default: 443).

.PARAMETER  Path
    Directory path to save SSL certificate(s).  

.PARAMETER  DownloadChain
    Save all chain certificates to file.  A certificate chain folder will be created under the specfied -path directory.  -DownloadChain is dependent on the path parameter.

.NOTES
    Name: Get-PortCertificate_WS
    Author: Caleb Keene
    Updated: 08-30-2016
    Version: 1.2

.EXAMPLE
    Get-PortCertificate_WS -Computername Server1 -Port 3389 -Path C:\temp -verbose

.EXAMPLE
    "server1","server2","server3" | Get-PortCertificate_WS 
#>   
 

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [Alias('IPAddress','Server','Computer')]              
        [string]$ComputerNameFQDN =  $env:COMPUTERNAME,  
        [Parameter(Mandatory = $false,Position = 1)]
        [ValidateRange(1,65535)]
        [int]$Port = 443,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$Path

    )

    #use a dynamic parameter to prevent -downloadchain without -path.
    DynamicParam {
        #Need some sort of conditional check before allowing Dynamic Parameter
        If ($PSBoundParameters.ContainsKey('Path')) {
            #Same as [Parameter()]
            $attribute = new-object System.Management.Automation.ParameterAttribute
            $attribute.Mandatory = $false
            $AttributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $AttributeCollection.Add($attribute)

            #Build out the Dynamic Parameter
            # Need the Parameter Name, Type and Attribute Collection (Built already)
            $DynamicParam = new-object -Type System.Management.Automation.RuntimeDefinedParameter("DownloadChain", [switch], $AttributeCollection)
            
            $ParamDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
            $ParamDictionary.Add("DownloadChain", $DynamicParam)
            return $ParamDictionary
        }
    }    

    Begin{
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        #make sure the version is supported
        if ($psversiontable.psversion.Major -le 2 ){
                Write-warning "Function requires PowerShell version 3 or later."
                break            
        }

        #add a custom type name to control our objects default display properties
        try{ Update-TypeData -TypeName 'Get.PortCertificate' -DefaultDisplayPropertySet Subject,Issuer,NotAfter,NotBefore,ExpiresIn,CertificateValidNames,TargetName,TargetNameStatus,TargetNameStatusDetails,TargetNameIsValid,ChainPath,ChainStatus,ChainStatusDetails,CertificateIsValid -ErrorAction stop}
        catch{}

        #validate that the path is a filesystem directory
        if ($path) { 

            if(-not(test-path -PathType Container FileSystem::$path)){
                Write-warning "The supplied directory path is not valid: $path"
                break
            }

        }
       
    }

    Process {
        
        #make sure we are able to establish a port connection

        #Set our connection timeout
        $timeout = 1000

        #Create object to test the port connection
        $tcpobject = New-Object System.Net.Sockets.TcpClient 

        #Connect to remote port               
        $connect = $tcpobject.BeginConnect($ComputerNameFQDN,$Port,$null,$null) 

        #Configure connection timeout
        $wait = $connect.AsyncWaitHandle.WaitOne($timeout,$false) 
        If (-NOT $Wait) {
            Write-Warning "[$($ComputerNameFQDN)] Connection to port $($Port) timed out after $($timeout) milliseconds"
            return
        } Else {
            Try {
                [void]$tcpobject.EndConnect($connect)
                Write-Verbose "[$($ComputerNameFQDN)] Successfully connected to port $($Port). Good!"
            } Catch {
                Write-Warning "[$($ComputerNameFQDN)] $_"
                return
            }
        } 

        #Note: This also works for validating the port connection, but the default timeout when unable to connect is a bit long.
        <#
        try {
            (New-Object system.net.sockets.tcpclient -ArgumentList $ComputerNameFQDN,$port -ErrorAction stop).Connected
        }
        catch{            
            Write-Warning ("Unable to connect to {0} on port {1}"-f$ComputerNameFQDN,$Port)
            return
        }
        #>

        Write-Verbose "[$($ComputerNameFQDN)] Getting SSL certificate from port $($Port)."

        #create our webrequest object for the ssl connection
        $sslrequest = [Net.WebRequest]::Create("https://$ComputerNameFQDN`:$port")

        #make the connection and store the response (if any).
        try{$Response = $sslrequest.GetResponse()}
        catch{}

        #load the returned SSL certificate using x509certificate2 class
        if ($certificate = [Security.Cryptography.X509Certificates.X509Certificate2]$sslrequest.ServicePoint.Certificate.Handle){
            . Validate-Certificate_WS -ComputerNameFQDN $ComputerNameFQDN -Certificate $certificate            
            #save our certificate(s) to file if applicable
            if ($path){
                write-verbose "Saving certificate(s) to file."

                try {
                    $psobject.RawData | Set-Content -Encoding Byte -Path "$path\Cert`_$ComputerNameFQDN`_$port`.cer" -ErrorAction stop
                    write-verbose "Certificate saved to $path\Cert`_$ComputerNameFQDN`_$port`.cer."
                }
                catch{write-warning ("Unable to save certificate to {0}: {1}" -f "$path\Cert`_$ComputerNameFQDN`_$port`.cer",$_.exception.message)}

                if($PSBoundParameters.ContainsKey('DownloadChain')){
                    
                    New-Item -ItemType directory -path "$path\ChainCerts`_$ComputerNameFQDN`_$port" -ErrorAction SilentlyContinue > $null
                    
                    $psobject.chaincertificates.certificates | % {
                        try {
                            Set-Content $_.RawData -Encoding Byte -Path "$path\ChainCerts`_$ComputerNameFQDN`_$port\$($_.thumbprint)`.cer" -ErrorAction stop
                            write-verbose "Certificate chain certificate saved to $path\ChainCerts`_$ComputerNameFQDN`_$port\$($_.thumbprint)`.cer."
                        }
                        catch{
                            write-warning ("Unable to save certificate chain certificate to {0}: {1}" -f "$path\ChainCerts`_$ComputerNameFQDN`_$port",$_.exception.message)
                        }
                    }
                }
            }

            #abort any connections
            $sslrequest.abort()
                              
        }

        else{
            #we were able to connect to the port but no ssl certificate was returned
            write-warning ("[{0}] No certificate returned on port {1}."-f $ComputerNameFQDN,$Port)

            #abort any connections
            $sslrequest.abort()

            return
        }
    }
}

new-alias -force Find-URLCertificate_WS Find-URLCertificateBindings_WS
Function Find-URLCertificateBindings_WS {
    param (
        [string[]]$URL,
        [switch]$UsePinningOnly
    )
    write-warning "Find-URLCertificate is still in progress."
    Get-FunctionReferenceCheck_WS
    $HttpListenerappid='{12345678-db90-4b66-8b01-88f7af2e36bf}'
    foreach ($URLItem in $URL) {
        if ($URLItem -match '^https') {
            $CertMatch = Find-ValidCertificate_WS $URLItem | select -First 1
            if ($null -eq $CertMatch) {
                $ShortURLItem=$URLItem -replace '\..*'
                $CertMatch = Find-ValidCertificate_WS $ShortURLItem
                Out-Log_WS -Message 'Using substitute certificate where the FQDN does not match.' -Data @{URL=$URL;Certificate=$CertMatch}
            }
            $hostnameport=(($URLItem -split '/')[2])
            if ($null -eq $CertMatch)         {Write-Warning -Message "CertMatch not found for URL: $URLItem"}
            elseif ($hostnameport -like ':*') {Write-Warning -Message "hostnameport incorrect: $hostnameport"}
            else {
                $NewURL+=$URLItem
                $DeleteSSLRegistrationSB = {
                    if ((netsh http show sslcert "hostnameport=$($this.hostnameport)") -match 'Hostname:port') {
                        netsh http delete sslcert "hostnameport=$($this.hostnameport)" 
                    }
                }

                $CreateSSLRegistrationScriptBlock={
                    $HttpListenerappid='{12345678-db90-4b66-8b01-88f7af2e36bf}'
                    $CMD = "netsh http add sslcert 'hostnameport=$($this.hostnameport)' 'certhash=$($this.Thumbprint)' 'certstorename=My' 'appid=$HttpListenerappid'"
                    Write-Verbose $CMD -Verbose
                    . ([scriptblock]::Create($CMD))
                }
                $Obj=[pscustomobject]@{
                    Name=$URLItem
                    Thumbprint=$CertMatch.Thumbprint
                    hostnameport=$hostnameport
                    Certificate=$CertMatch
                }
                Add-Member -InputObject $obj -MemberType ScriptMethod -Name CreateSSLRegistration -Value $CreateSSLRegistrationScriptBlock
                Add-Member -InputObject $obj -MemberType ScriptMethod -Name DeleteSSLRegistration -Value $DeleteSSLRegistrationSB
                $Obj
            }
        }
        else {
            [pscustomobject]@{
                Name=$URLItem
                Thumbprint=$null
                ScriptBlock=$null
                Certificate=$null
            }
        }
    }
}

Function Set-URLCertificate_WS {
    param (
        [string[]]$URL,
        $Certificate
    )
    write-warning "Set-URLCertificate is still in progress."
    $HttpListenerappid='{12345678-db90-4b66-8b01-88f7af2e36bf}'
    $NewURL =@()
    foreach ($URLItem in $URL) {
        if ($URLItem -match '^https') {
            $CertMatch = Find-ValidCertificate_WS $URLItem | select -First 1
            if ($null -eq $CertMatch) {
                $ShortURLItem=$URLItem -replace '\..*'
                $CertMatch = Find-ValidCertificate_WS $ShortURLItem
                Out-Log_WS -Message 'Using substitute certificate where the FQDN does not match.' -Data @{URL=$URL;Certificate=$CertMatch}
            }
            $hostnameport=(($URLItem -split '/')[2])
            if ($null -eq $CertMatch)         {Write-Warning -Message "CertMatch not found for URL: $URLItem"}
            elseif ($hostnameport -like ':*') {Write-Warning -Message "hostnameport incorrect: $hostnameport"}
            else {
                $NewURL+=$URLItem
                if ((netsh http show sslcert hostnameport=$hostnameport) -match 'Hostname:port') {
                    netsh http delete sslcert hostnameport=$hostnameport 
                }
                $CMD = "netsh http add sslcert 'hostnameport=$hostnameport' 'certhash=$($CertMatch.Thumbprint)' 'certstorename=My' 'appid=$HttpListenerappid'"
                $ScriptBlock=[scriptblock]::create($CMD)
                Write-Verbose $CMD -Verbose
                & $ScriptBlock
                [pscustomobject]@{
                    Name=$URLItem
                    Thumbprint=$CertMatch.Thumbprint
                    ScriptBlock=$ScriptBlock
                    HttpListenerappid=$HttpListenerappid
                }
            }
        }
        else {
            [pscustomobject]@{
                Name=$URLItem
                Thumbprint=$null
                ScriptBlock=$null
                HttpListenerappid=$HttpListenerappid
            }
        }
    }
}
