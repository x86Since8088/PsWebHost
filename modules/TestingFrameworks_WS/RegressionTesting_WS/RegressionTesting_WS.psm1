#Regression Testing

function Debug_WS {
    begin {$error.clear()}
    process {
        $_
        if ($Error.count) {
            Out-Log_WS -Message "Debug_WS: Error intercepted" -data @{
                Error=$error
                PSCallstack=Get-PSCallStack
            }
        }
    }
}

function Test-Feature_WS {
    Param (
        [validateset(
            '*',
            'JWT',
            'ConvertFrom-Jwt'
        )][string[]]$Name = '*'
    )
    $AllNames = 'JWT',
            'ConvertFrom-Jwt'
    if ($Name -eq '*') {$Name = $AllNames}
    if ($Name.count -eq 0) {
        $Source = $MyInvocation.MyCommand.Module.Path + '\' + $MyInvocation.MyCommand.Definition
        out-log_WS -Message "-Name is empty in $Source" -Data (write-error -Message "-Name is empty." 2>&1)
        return
    }
    switch ($Name) {
        'JWT' {
            Get-BaseLineScan_DOES -Title $_ `
             -Criteria @{
                #Name is a required string that names a specific check and remediation intent.
                Name='Test JWT RS256 signature and validation'
        
                #Test is a required scriptblock that is always ran.
                Test={
                    #Always save your test output to a variable named $TestData so it can be referenced later.
                    $Error.Clear()
                    $TestJWTClaim = New-JWTClaim -Issuer Test-Feature_WS -Subject 'TestUser'
                    $JwtCertificate = Get-JWTCertificate
                    $TestJWT = New-Jwt -PayloadJson $TestJWTClaim -Cert $JwtCertificate.certificate -Verbose
                    $TestTestJWT = Test-Jwt -jwt $TestJWT -Cert $JwtCertificate.Certificate -Verbose
                    $TestData = [pscustomobject]@{
                        TestJWTClaim = $TestJWTClaim
                        JwtCertificate = $JwtCertificate
                        TestJWT = $TestJWT
                        TestTestJWT=$TestTestJWT
                        Error=$Error
                    }
                    #Return the collected output
                    $TestData
                }
    
                #Test is a required scriptblock that is always ran as a Where-Object scriptblock.
                Evaluation={
                    #This is a comparison operation that results in true or false, so anything that is not $null, 0, or false will resolve into $True.
                    #  TRUE is a PASS 
                    $TestTestJWT -eq $True
                }
    
                #Remediate is recommended.  It is only run when the evaluation value resolved to $True and the -Apply is $True.
                Remediate={
                    'No automatic remediation'
                }
            }
        }

        'ConvertFrom-Jwt' {
            Get-BaseLineScan_DOES -Title $_ `
             -Criteria @{
                #Name is a required string that names a specific check and remediation intent.
                Name='Test ConvertFrom-JWT against a token created by New-JWT and NewJWTClaim.'
        
                #Test is a required scriptblock that is always ran.
                Test={
                    #Always save your test output to a variable named $TestData so it can be referenced later.
                    $Error.Clear()
                    $TestJWTClaim = New-JWTClaim -Issuer Test-Feature_WS -Subject 'TestUser'
                    $JwtCertificate = Get-JWTCertificate
                    $TestJWT = New-Jwt -PayloadJson $TestJWTClaim -Cert $JwtCertificate.certificate -Verbose
                    $TestConvertFromJWT = ConvertFrom-Jwt -Token $TestJWT  
                    $TestData = [pscustomobject]@{
                        TestJWTClaim = $TestJWTClaim
                        JwtCertificate = $JwtCertificate
                        TestJWT = $TestJWT
                        TestConvertFromJWT=$TestConvertFromJWT
                        Error=$Error
                    }
                    #Return the collected output
                    $TestData
                }
    
                #Test is a required scriptblock that is always ran as a Where-Object scriptblock.
                Evaluation={
                    #This is a comparison operation that results in true or false, so anything that is not $null, 0, or false will resolve into $True.
                    #  TRUE is a PASS 
                    (ConvertFrom-Jwt -Token $TestJWT).iss -eq 'Test-Feature_WS'
                }
    
                #Remediate is recommended.  It is only run when the evaluation value resolved to $True and the -Apply is $True.
                Remediate={
                    'No automatic remediation'
                }
            }
        }

        default {'Unhandled test name: ' + $_}
    }

}