    $Request = $context.request
    # get post data.
    $data = extract $request
    write-host Post Data: ($data | out-string)
    $Request.headers | %{
        write-host $_ :($Request.headers[$_] )
    }
    
    $DataDecoded = @{}
    foreach ($key in $data.Keys) {
        [string]$Value=''
        $Name = Decode-URL_WS $key
        $Value= Decode-URL_WS $data[$key]
        $DataDecoded.add($Name,$Value)
    }
    $cookie = $Request.cookies['']
    [string]$UserName = $DataDecoded['username']
    [securestring]$password = $DataDecoded['password'] | ConvertTo-SecureString -AsPlainText -Force
    $Cred = [pscredential]::new($UserName,$password)
    $test = Test-Cred_WS -Credentials $Cred
    if ($DataDecoded['logoff'] -eq 1) {}
    switch ($test) {
        'Authenticated' {
            $Domain = ($UserName -split '\\' |select -First 1) -split '@' | select -Last 1
            $UName = ($UserName -split '\\' |select -last 1) -split '@' | select -First 1
            $ADuser = Get-ADUser -Server $Domain -AuthType Negotiate -Credential $Cred -Identity $UName
            $JWT = Set-ResponseAuthentication_WS -UserName $UserName -Name $password
        }
        'Not Authenticated' {
            $context.response.statuscode = 404
        }
    }
    $result = @{
        Test=$test
        Data=[pscustomobject]$DataDecoded
        JWT=$JWT
    }
    write-host ($result | format-table -AutoSize | out-string)
    return ($result | ConvertTo-Json)
#Get-ResponseAuthentication_WS