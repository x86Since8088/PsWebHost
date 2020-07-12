###################################
# Declare URLs that will be used.
###################################
$FQDN = $([System.Net.Dns]::Resolve($env:COMPUTERNAME)).hostname
[string[]]$url = @(
    "http://localhost:8080/"
    "https://localhost:8443/"
    "http://$env:COMPUTERNAME`:8080/"
    "https://$env:COMPUTERNAME`:8443/"
    "http://$FQDN`:8080/"
    "https://$FQDN`:8443/"
)

$BindingsCSVFile = "$Global:Project_Root\Bindings.csv"
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
}


#############################################
# Dynamically assign certificates for https
#############################################
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
$URL = $NewURL
$FirstHttpURL=$URL|?{$_ -notmatch 'https:'}|select -First 1

