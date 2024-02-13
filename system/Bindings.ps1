###################################
# Declare URLs that will be used.
###################################
$FQDN                                             = ([System.Net.Dns]::Resolve($env:COMPUTERNAME)).hostname
$Global:PSWebServer.Project_Data.bindings         = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Data.Path + '\bindings'})
                                                    $Global:PSWebServer.Project_Data.bindings.Path |
                                                        Where-Object{! (test-path $_)}|
                                                        Foreach-Object{ mkdir $_ }

$Global:PSWebServer.Project_Data.bindings.FQDN    = $FQDN
[string[]]$url                                    = 
                                                    @(
                                                        "http://localhost:8080/"
                                                        "https://localhost:8443/"
                                                        "http://$env:COMPUTERNAME`:8080/"
                                                        "https://$env:COMPUTERNAME`:8443/"
                                                        "http://$FQDN`:8080/"
                                                        "https://$FQDN`:8443/"
                                                    )

$InternalCACert                                   = Get-ChildItem  Cert:\LocalMachine\My\ | Where-Object{$_.Subject -eq 'SN=TestRootCA'}
$ExpiryInYears                                    = 10
                                                    if ($null -eq $InternalCACert) {
                                                        $InternalCACert = New-SelfSignedCertificate `
                                                            -FriendlyName "MyCA" `
                                                            -KeyExportPolicy ExportableEncrypted `
                                                            -Provider "Microsoft Strong Cryptographic Provider" `
                                                            -Subject "SN=TestRootCA" `
                                                            -NotAfter (Get-Date).AddYears($ExpiryInYears) `
                                                            -KeyUsageProperty All `
                                                            -KeyUsage CertSign, CRLSign, DigitalSignature `
                                                            -CertStoreLocation Cert:\LocalMachine\My 
                                                    }
                                                    $Global:PSWebServer.Project_Data.bindings.InternalCACertThumbprint = $InternalCACert.Thumbprint

                                                    <#
                                                    New-SelfSignedCertificate -CertStoreLocation  Cert:\CurrentUser\My `
                                                        -KeyLength 2048  `
                                                        -Subject * -DnsName * `
                                                        -NotAfter (get-date).AddDays(360) `
                                                        -Verbose -HashAlgorithm sha256 `
                                                        -Provider "Microsoft Strong Cryptographic Provider" `
                                                        -CurveExport "ECDSA_P256" `
                                                        -Extension "Server Authentication" `
                                                        -KeyAlgorithm "RSA" `
                                                        #>

$BindingsCSVFile = "$($Global:PSWebServer.Project_Data.bindings.Path)\\Bindings.csv"
$Global:PSWebServer.Project_Data.bindings.BindingsCSVFile = $BindingsCSVFile
if (-not (test-path $BindingsCSVFile)) {
    $DefaultBindings = @{
        Name="http://localhost:8080/"
    },
    @{
        Name="https://localhost:8443/"
        Certificate=''
    },
    @{
        Name="http://$env:COMPUTERNAME`:8080/"
    },
    @{
        Name="https://$env:COMPUTERNAME`:8443/"
        Certificate=''
    }
    $DefaultBindings|Export-Csv -Path $BindingsCSVFile -NoTypeInformation
}
$Global:PSWebServer.Project_Data.bindings.DefaultBindings

#############################################
# Dynamically assign certificates for https
#############################################
$HttpListenerappid='{12345678-db90-4b66-8b01-88f7af2e36bf}'
$NewURL =@()
foreach ($URLItem in $URL) {
    if ($URLItem -match '^https') {
        $CertMatch = Find-ValidCertificate_WS $URLItem | Select-Object -First 1
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
            Write-Verbose $CMD -Verbose
            & ([scriptblock]::create($CMD))
        }
    }
    else {$NewURL+=$URLItem}
}

#############################################
# Show the final list of URLs to be used.
#############################################
$NewURL
[array]$URL = $NewURL
$FirstHttpURL=$URL|Where-Object{$_ -notmatch 'https:'}|Select-Object -First 1
$Global:PSWebServer.Project_Data.bindings.url     = $url
$Global:PSWebServer.Project_Data.bindings.FirstHttpURL     = $url
