
#https://www.powershellgallery.com/packages/JWT/1.1.0/Content/JWT.psm1

Import-Module "$(split-path $PSScriptRoot)\Set-MissingContentItems_WS"

function New-Jwt {
<#
.SYNOPSIS
Creates a JWT (JSON Web Token).
.DESCRIPTION
Creates signed JWT given a signing certificate and claims in JSON.
.PARAMETER Payload
Specifies the claim to sign in JSON. Mandatory.
.PARAMETER Cert
Specifies the signing certificate. Mandatory.
.PARAMETER Header
Specifies a JWT header. Optional. Defaults to '{"alg":"RS256","typ":"JWT"}'.
.INPUTS
You can pipe a string object (the JSON payload) to New-Jwt.
.OUTPUTS
System.String. New-Jwt returns a string with the signed JWT.
.EXAMPLE
PS Variable:\> $cert = (Get-ChildItem Cert:\CurrentUser\My)[1]
PS Variable:\> New-Jwt -Cert $cert -PayloadJson '{"token1":"value1","token2":"value2"}'
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbjEiOiJ2YWx1ZTEiLCJ0b2tlbjIiOiJ2YWx1ZTIifQ.Kd12ryF7Uuk9Y1UWsqdSk6cXNoYZBf9GBoqcEz7R5e4ve1Kyo0WmSr-q4XEjabcbaG0hHJyNGhLDMq6BaIm-hu8ehKgDkvLXPCh15j9AzabQB4vuvSXSWV3MQO7v4Ysm7_sGJQjrmpiwRoufFePcurc94anLNk0GNkTWwG59wY4rHaaHnMXx192KnJojwMR8mK-0_Q6TJ3bK8lTrQqqavnCW9vrKoWoXkqZD_4Qhv2T6vZF7sPkUrgsytgY21xABQuyFrrNLOI1g-EdBa7n1vIyeopM4n6_Uk-ttZp-U9wpi1cgg2pRIWYV5ZT0AwZwy0QyPPx8zjh7EVRpgAKXDAg
.EXAMPLE
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("/mnt/c/PS/JWT/jwt.pfx","jwt")
$now = (Get-Date).ToUniversalTime()
$createDate = [Math]::Floor([decimal](Get-Date($now) -UFormat "%s"))
$expiryDate = [Math]::Floor([decimal](Get-Date($now.AddHours(1)) -UFormat "%s"))
$rawclaims = [Ordered]@{
    iss = "examplecom:apikey:uaqCinPt2Enb"
    iat = $createDate
    exp = $expiryDate
} | ConvertTo-Json
$jwt = New-Jwt -PayloadJson $rawclaims -Cert $cert
$apiendpoint = "https://api.example.com/api/1.0/systems"
$splat = @{
    Method="GET"
    Uri=$apiendpoint
    ContentType="application/json"
    Headers = @{authorization="bearer $jwt"}
}
Invoke-WebRequest @splat
.LINK
https://github.com/SP3269/posh-jwt
.LINK
https://jwt.io/
#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)][string]$Header = '{"alg":"RS256","typ":"JWT"}',
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$PayloadJson,
        [Parameter(Mandatory=$true)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
    )

    Write-Verbose "Payload to sign: $PayloadJson"
    Write-Verbose "Signing certificate: $($Cert.Subject)"

    try { ConvertFrom-Json -InputObject $payloadJson -ErrorAction Stop | Out-Null } # Validating that the parameter is actually JSON - if not, generate breaking error
    catch { throw "The supplied JWT payload is not JSON: $payloadJson"}

    $encodedHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Header)) -replace '\+','-' -replace '/','_' -replace '='
    $encodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($PayloadJson)) -replace '\+','-' -replace '/','_' -replace '='

    $jwt = $encodedHeader + '.' + $encodedPayload # The first part of the JWT

    $toSign = [System.Text.Encoding]::UTF8.GetBytes($jwt)
    
    [System.Security.Cryptography.RSA]$rsa = $Cert.PrivateKey
    if ($null -eq $rsa) { # Requiring the private key to be present; else cannot sign!
        throw "There's no private key in the supplied certificate - cannot sign" 
    }
    else {
        # Overloads tested with RSACryptoServiceProvider, RSACng, RSAOpenSsl
        [Security.Cryptography.HashAlgorithmName]$SignatureAlgorithm = ('SHA' + ($rsa.SignatureAlgorithm -split '-' |?{$_ -match 'sha'} | %{[int]$_.replace('sha','')} | sort -Descending | select -First 1))

        <#
        #if ($SignatureAlgorithm.name -eq 'sha1') {
        #    Write-error -Message "Certificate private key has only SHA1 SignatureAlgorithm: $($cert.Thumbprint) $($cert.subject)"
        #}
        #$sig = [Convert]::ToBase64String($rsa.SignData($toSign,$SignatureAlgorithm,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) -replace '\+','-' -replace '/','_' -replace '=' 
        #$sig = [Convert]::ToBase64String($rsa.SignData($toSign,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) -replace '\+','-' -replace '/','_' -replace '=' 
        #$sig = [Convert]::ToBase64String($rsa.SignData($toSign,[Security.Cryptography.HashAlgorithmName]::SHA256)) -replace '\+','-' -replace '/','_' -replace '=' 
        #>
        <#
            However you get there, once you've obtained a certificate with a private key we need to reconstruct it. 
            This may be required due to the way the certificate creates it's private key, but I'm not really sure why. 
            Anyway, we do this by first exporting the key and then re-importing it using whatever intermediate format you 
            like, the easiest is xml:
        #>
        #[System.Security.Cryptography.RSACryptoServiceProvider] $key = [System.Security.Cryptography.RSACryptoServiceProvider]::new();
        #$key.FromXmlString($rsa.ToXmlString(0));
        #$sig = [Convert]::ToBase64String($key.SignData($toSign,[System.Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'))) -replace '\+','-' -replace '/','_' -replace '=' 

        # Force use of the Enhanced RSA and AES Cryptographic Provider with openssl-generated SHA256 keys
        $enhCsp = [System.Security.Cryptography.RSACryptoServiceProvider]::new().CspKeyContainerInfo;
        $cspparams = [System.Security.Cryptography.CspParameters]::new($enhCsp.ProviderType, $enhCsp.ProviderName, $rsa.CspKeyContainerInfo.KeyContainerName);
        $privKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspparams);
        $sig = [Convert]::ToBase64String($privKey.SignData($toSign,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) -replace '\+','-' -replace '/','_' -replace '=' 
            #[System.Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256')

        try { }
        catch { throw "Signing with SHA256 and Pkcs1 padding failed using private key $rsa" }
    }

    $jwt = $jwt + '.' + $sig

    return $jwt

}

function Test-Jwt {
<#
.SYNOPSIS
Tests cryptographic integrity of a JWT (JSON Web Token).
.DESCRIPTION
Verifies a digital signature of a JWT given a signing certificate. Assumes SHA-256 hashing algorithm. Optionally produces the original signed JSON payload.
.PARAMETER Payload
Specifies the JWT. Mandatory string.
.PARAMETER Cert
Specifies the signing certificate. Mandatory X509Certificate2.
.INPUTS
You can pipe JWT as a string object to Test-Jwt.
.OUTPUTS
Boolean. Test-Jwt returns $true if the signature successfully verifies.
.EXAMPLE
PS Variable:> $jwt | Test-Jwt -cert $cert -Verbose
VERBOSE: Verifying JWT: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbjEiOiJ2YWx1ZTEiLCJ0b2tlbjIiOiJ2YWx1ZTIifQ.Kd12ryF7Uuk9Y1UWsqdSk6cXNoYZBf9GBoqcEz7R5e4ve1Kyo0WmSr-q4XEjabcbaG0hHJyNGhLDMq6BaIm-hu8ehKgDkvLXP
Ch15j9AzabQB4vuvSXSWV3MQO7v4Ysm7_sGJQjrmpiwRoufFePcurc94anLNk0GNkTWwG59wY4rHaaHnMXx192KnJojwMR8mK-0_Q6TJ3bK8lTrQqqavnCW9vrKoWoXkqZD_4Qhv2T6vZF7sPkUrgsytgY21xABQuyFrrNLOI1g-EdBa7n1vIyeopM4n6_Uk-ttZp-U9wpi1cgg2p
RIWYV5ZT0AwZwy0QyPPx8zjh7EVRpgAKXDAg
VERBOSE: Using certificate with subject: CN=jwt_signing_test
True
.LINK
https://github.com/SP3269/posh-jwt
.LINK
https://jwt.io/
#>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$jwt,
        [Parameter(Mandatory=$true)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
    )

    Write-Verbose "Verifying JWT: $jwt"
    Write-Verbose "Using certificate with subject: $($Cert.Subject)"

    $parts = $jwt.Split('.')

    if ($OutputJSON) {
        $OutputJSON.value = [Convert]::FromBase64String($parts[1].replace('-','+').replace('_','/'))
    }

    $SHA256 = New-Object Security.Cryptography.SHA256Managed
    $computed = $SHA256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($parts[0]+"."+$parts[1])) # Computing SHA-256 hash of the JWT parts 1 and 2 - header and payload
    
    $signed = $parts[2].replace('-','+').replace('_','/') # Decoding Base64url to the original byte array
    $mod = $signed.Length % 4
    switch ($mod) {
        0 { $signed = $signed }
        1 { $signed = $signed.Substring(0,$signed.Length-1) }
        2 { $signed = $signed + "==" }
        3 { $signed = $signed + "=" }
    }
    $bytes = [Convert]::FromBase64String($signed) # Conversion completed

    # Force use of the Enhanced RSA and AES Cryptographic Provider with openssl-generated SHA256 keys
    $enhCsp = [System.Security.Cryptography.RSACryptoServiceProvider]::new().CspKeyContainerInfo;
    $cspparams = [System.Security.Cryptography.CspParameters]::new($enhCsp.ProviderType, $enhCsp.ProviderName, $cert.PublicKey.CspKeyContainerInfo.KeyContainerName);
    $Publickey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspparams);

    return $Publickey.VerifyHash($computed,$bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) # Returns True if the hash verifies successfully

}

New-Alias -Name "Verify-JwtSignature" -Value "Test-Jwt" -Description "An alias, using non-standard verb"

function Get-JwtPayload {
    <#
    .SYNOPSIS
    Gets JSON payload from a JWT (JSON Web Token).
    
    .DESCRIPTION
    Decodes and extracts JSON payload from JWT. Ignores headers and signature.
    
    .PARAMETER Payload
    Specifies the JWT. Mandatory string.
    
    .INPUTS
    You can pipe JWT as a string object to Get-JwtPayload.
    
    .OUTPUTS
    String. Get-JwtPayload returns $true if the signature successfully verifies.
    
    .EXAMPLE
    
    PS Variable:> $jwt | Get-JwtPayload -Verbose
    VERBOSE: Processing JWT: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbjEiOiJ2YWx1ZTEiLCJ0b2tlbjIiOiJ2YWx1ZTIifQ.Kd12ryF7Uuk9Y1UWsqdSk6cXNoYZBf9GBoqcEz7R5e4ve1Kyo0WmSr-q4XEjabcbaG0hHJyNGhLDMq6BaIm-hu8ehKgDkvLXPCh15j9AzabQB4vuvSXSWV3MQO7v4Ysm7_sGJQjrmpiwRoufFePcurc94anLNk0GNkTWwG59wY4rHaaHnMXx192KnJojwMR8mK-0_Q6TJ3bK8lTrQqqavnCW9vrKoWoXkqZD_4Qhv2T6vZF7sPkUrgsytgY21xABQuyFrrNLOI1g-EdBa7n1vIyeopM4n6_Uk-ttZp-U9wpi1cgg2pRIWYV5ZT0AwZwy0QyPPx8zjh7EVRpgAKXDAg
    {"token1":"value1","token2":"value2"}
    
    .LINK
    https://github.com/SP3269/posh-jwt
    .LINK
    https://jwt.io/
    
    #>
    
    
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$jwt
        )
    
        Write-Verbose "Processing JWT: $jwt"
            
        $parts = $jwt.Split('.')
    
        $payload = $parts[1].replace('-','+').replace('_','/') # Decoding Base64url to the original byte array
        $mod = $payload.Length % 4
        switch ($mod) {
            # 0 { $payload = $payload } - do nothing
            1 { $payload = $payload.Substring(0,$payload.Length-1) }
            2 { $payload = $payload + "==" }
            3 { $payload = $payload + "=" }
        }
        $bytes = [Convert]::FromBase64String($payload) # Conversion completed

        return [System.Text.Encoding]::UTF8.GetString($bytes)
    
    }

function Generate-JWT {
    param (
        [Parameter(Mandatory = $True)]
        [ValidateSet("HS256", "HS384", "HS512")]
        $Algorithm = "HS256",
        $type = $null,
        [Parameter(Mandatory = $True)]
        [string]$Issuer = $null,
        [int]$ValidforSeconds = $null,
        [Parameter(Mandatory = $True)]
        $SecretKey = $null
    )

    $exp = [int][double]::parse((Get-Date -Date $((Get-Date).addseconds($ValidforSeconds).ToUniversalTime()) -UFormat %s)) # Grab Unix Epoch Timestamp and add desired expiration.

    [hashtable]$header = @{alg = $Algorithm; typ = $type}
    [hashtable]$payload = @{iss = $Issuer; exp = $exp}

    $headerjson = $header | ConvertTo-Json -Compress
    $payloadjson = $payload | ConvertTo-Json -Compress
    
    $headerjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($headerjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')
    $payloadjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')

    $ToBeSigned = $headerjsonbase64 + "." + $payloadjsonbase64

    $SigningAlgorithm = switch ($Algorithm) {
        "HS256" {New-Object System.Security.Cryptography.HMACSHA256}
        "HS384" {New-Object System.Security.Cryptography.HMACSHA384}
        "HS512" {New-Object System.Security.Cryptography.HMACSHA512}
    }

    $SigningAlgorithm.Key = [System.Text.Encoding]::UTF8.GetBytes($SecretKey)
    $Signature = [Convert]::ToBase64String($SigningAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ToBeSigned))).Split('=')[0].Replace('+', '-').Replace('/', '_')
    
    $token = "$headerjsonbase64.$payloadjsonbase64.$Signature"
    $token
}

Set-MissingContentItems_WS -Path "$Global:Project_Root\Data\JWT\JWT_HS_key" -GlobalVariableName JWT_HS_key -Text ((New-Guid).guid + (New-Guid).guid -replace '-')
Set-MissingContentItems_WS -Path "$Global:Project_Root\Data\JWT\JWT_HS_key" -GlobalVariableName JWT_HS_secret -Text ((New-Guid).guid + (New-Guid).guid -replace '-')
#$api_key =  JWT_HS_key
#$api_secret = JWT_HS_secret

#Generate-JWT -Algorithm 'HS256' -type 'JWT' -Issuer $api_key -SecretKey $api_secret -ValidforSeconds 30    

Function New-MSIdentitycertificateAuth {
    <#
        Sample to connect to Graph using a certificate to authenticate

        Prerequisite : ADAL (Microsoft.IdentityModel.Clients.ActiveDirectory.dll)

    #>

    # Load the ADAL Assembly
    Add-Type -Path "E:\Assemblies\Microsoft.IdentityModel.Clients.ActiveDirectory.4.3.0\lib\net45\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"

    # Settings for the application
    $AppID = '<ID OF THE WEB APP>'
    $TenantDomain = '<TENANT>'
    $LoginUri = 'https://login.microsoftonline.com/'
    $Resource = 'https://graph.microsoft.com'
    $Certificate = Get-Item 'Cert:\CurrentUser\My\<CERTIFICATE THUMBPRINT>' # This points to my own certificate

    # Auth Authority Uri
    $Authority = "$LoginUri/$TenantDomain"
    # Create the authenticationContext
    $Context = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($Authority)
    # create the CAC
    $CAC = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientAssertionCertificate]::new($AppID,$Certificate)
    # Get the token
    $TokenResponse = $Context.AcquireTokenAsync($Resource,$CAC)

    Start-Sleep -Seconds 1 # Sleep for 1 second...

    # Token should be present
    $TokenResult = $TokenResponse.Result
}


function Parse-JWTtoken {
 
    [cmdletbinding()]
    param([Parameter(Mandatory=$true)][string]$token)
 
    #Validate as per https://tools.ietf.org/html/rfc7519
    #Access and ID tokens are fine, Refresh tokens will not work
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    #Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenheader.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenheader += "=" }
    Write-Verbose "Base64 encoded (padded) header:"
    Write-Verbose $tokenheader
    #Convert from Base64 encoded string to PSObject all at once
    Write-Verbose "Decoded header:"
    [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json | fl | Out-Default
 
    #Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenPayload.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenPayload += "=" }
    Write-Verbose "Base64 encoded (padded) payoad:"
    Write-Verbose $tokenPayload
    #Convert to Byte array
    $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
    #Convert to string array
    $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)
    Write-Verbose "Decoded array in JSON format:"
    Write-Verbose $tokenArray
    #Convert from JSON to PSObject
    $tokobj = $tokenArray | ConvertFrom-Json
    Write-Verbose "Decoded Payload:"
    
    return $tokobj
}

function ConvertFrom-Jwt {

[cmdletbinding()]
param(
[Parameter(Mandatory = $true)]
[string]$Token,

[Alias(‘ih’)]
[switch]$IncludeHeader
)

# Validate as per https://tools.ietf.org/html/rfc7519
# Access and ID tokens are fine, Refresh tokens will not work
if (!$Token.Contains(“.”) -or !$Token.StartsWith(“eyJ”)) { Write-Error “Invalid token” -ErrorAction Stop }

# Extract header and payload
$tokenheader, $tokenPayload = $Token.Split(“.”).Replace(‘-‘, ‘+’).Replace(‘_’, ‘/’)[0..1]

# Fix padding as needed, keep adding “=” until string length modulus 4 reaches 0
while ($tokenheader.Length % 4) { Write-Debug “Invalid length for a Base-64 char array or string, adding =”; $tokenheader += “=” }
while ($tokenPayload.Length % 4) { Write-Debug “Invalid length for a Base-64 char array or string, adding =”; $tokenPayload += “=” }

Write-Debug “Base64 encoded (padded) header:`n$tokenheader”
Write-Debug “Base64 encoded (padded) payoad:`n$tokenPayload”

# Convert header from Base64 encoded string to PSObject all at once
$header = [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json
Write-Debug “Decoded header:`n$header”

# Convert payload to string array
$tokenArray = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tokenPayload))
Write-Debug “Decoded array in JSON format:`n$tokenArray”

# Convert from JSON to PSObject
$tokobj = $tokenArray | ConvertFrom-Json
Write-Debug “Decoded Payload:”

if($IncludeHeader) {$header}
return $tokobj
}

Function New-JWTClaim {
    param (
        [string]$Issuer = (($url | ?{$_ -match '^https.*?\w\.\w'} | sort length -Descending | select -First 1) + 'api/auth') ,
        [string]$Subject,
        [string]$Name,
        [string[]]$GroupNames,
        [string]$Audience,
        [datetime]$NotBefore=(get-date).addhours(-1),
        [int]$ValidforSeconds = 30,
        [string]$jti=(Get-Random -SetSeed (get-date).Millisecond -Minimum 1000000000 -Maximum 9999999999)
    )
    $nbf = [int][double]::parse((Get-Date -Date $($NotBefore.ToUniversalTime()) -UFormat %s)) # Grab Unix Epoch Timestamp and add desired Not Before.
    $iat = [int][double]::parse((Get-Date -Date $((Get-Date).addseconds(0).ToUniversalTime()) -UFormat %s)) # Grab Unix Epoch Timestamp and add desired expiration.
    $exp = [int][double]::parse((Get-Date -Date $((Get-Date).addseconds($ValidforSeconds).ToUniversalTime()) -UFormat %s)) # Grab Unix Epoch Timestamp and add desired expiration.
    $HT=@{
        iss=$Issuer    
        iat=$iat
        exp=$exp
        nbf=$nbf
    }
    if ($Subject -ne '') {$HT.add('sub',$Subject)}
    if ($Name -ne '') {$HT.add('nam',$Name)}
    if ($Audience -ne '') {$HT.add('aud',$Audience)}
    $GroupNames | Where-Object{$_} | sort -Unique | ForEach-Object{$HT.Add($_,$true)}
    $HT|ConvertTo-Json

}


Function Get-JWTCertificate {
    param (
        $Hostname = '*'
    )
    if ($null -eq $Global:CertBindings) {
        $Global:CertBindings = Find-URLCertificateBindings_WS -URL $url | Where-Object{$null -ne $_.Certificate}
    }
    $Global:CertBindings | 
    where-object{$_.hostnameport -like $Hostname} |
    Select *,@{Name='Length';Expression={$_.Name.Length}}|
    sort length -Descending | 
    select -First 1 ($Global:CertBindings[0].psobject.Properties.name|
    where-object{$_ -ne 'length'})
}

Function SignDataWithExportedCertificate1 {
    param (
        [string]$KeyStoreFile,
        [securestring]$Password,
        [string]$ToSign
    )
    [byte[]]$Data = [convert]::ToByte($ToSign)
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($KeyStoreFile, $Password);
    [System.Security.Cryptography.RSA] $rsacsp = [System.Security.Cryptography.RSA]::Create($cert.PrivateKey)
    [System.Security.Cryptography.CspParameters] $cspParam = [System.Security.Cryptography.CspParameters]::new();
    $cspParam.KeyContainerName = $rsacsp.CspKeyContainerInfo.KeyContainerName;
    $cspParam.KeyNumber = if ($rsacsp.CspKeyContainerInfo.KeyNumber -eq [System.Security.Cryptography.KeyNumber]::Exchange) {1} ELSE {2};
    [System.Security.Cryptography.RSACryptoServiceProvider] $aescsp = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspParam);
    $aescsp.PersistKeyInCsp = $false;
    [byte[]] $signed = $aescsp.SignData($Data, "SHA256");
    [bool] $isValid = $aescsp.VerifyData($Data, "SHA256", $signed);
}

Function SignDataWithExportedCertificate {
    param (
        [string]$KeyStoreFile,
        [securestring]$Password,
        [string]$ToSign
    )
    [byte[]]$Data = [convert]::ToByte($ToSign)
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($KeyStoreFile, $Password);
    [System.Security.Cryptography.RSA] $rsacsp = [System.Security.Cryptography.RSA]::Create($cert.PrivateKey)
    [System.Security.Cryptography.CspParameters] $cspParam = [System.Security.Cryptography.CspParameters]::new();
    $cspParam.KeyContainerName = $rsacsp.CspKeyContainerInfo.KeyContainerName;
    $cspParam.KeyNumber = if ($rsacsp.CspKeyContainerInfo.KeyNumber -eq [System.Security.Cryptography.KeyNumber]::Exchange) {1} ELSE {2};
    [System.Security.Cryptography.RSA] $aescsp = [System.Security.Cryptography.RSA]::new($cspParam);
    $aescsp.PersistKeyInCsp = $false;
    [byte[]] $signed = $aescsp.SignData($Data, "SHA256");
    [bool] $isValid = $aescsp.VerifyData($Data, "SHA256", $signed);
}

Function Get-CertificateFromFile {
    param (
        [string]$KeyStoreFile,
        [securestring]$Password
    )
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($KeyStoreFile, $Password);
    $cert
}
