Function Convert-CertificateToNewCSP {
    param (
        $Certificate,
        $CryptographicProvider
    )
    #Microsoft Enhanced RSA and AES Cryptographic Provider
    
    $enhCsp = [System.Security.Cryptography.RSACryptoServiceProvider]::new().CspKeyContainerInfo;
    $cspparams = [System.Security.Cryptography.CspParameters]::new($enhCsp.ProviderType, $enhCsp.ProviderName, $Certificate.PrivateKey.CspKeyContainerInfo.KeyContainerName);
    $PrivateKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspparams);

    $publicenhCsp = [System.Security.Cryptography.RSACryptoServiceProvider]::new().CspKeyContainerInfo;
    $publiccspparams = [System.Security.Cryptography.CspParameters]::new($publicenhCsp.ProviderType, $publicenhCsp.ProviderName, $Certificate.PublicKey.key.CspKeyContainerInfo.KeyContainerName);
    $PublicKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspparams);

}