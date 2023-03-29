Function Get-Credential {
    write-host -ForegroundColor Magenta -Message "Get-Credential was called and intercepted! $(((Get-PSCallStack|select * | fl|out-string) |%{$_;"-----------------"}) -split '\n' -replace '\s*$' |?{$_} | %{"`n|`t$_"} )"
    return [pscredential]::new('anonymous','')
}

Function Read-host {
    write-host -ForegroundColor Magenta -Message "Read-Host was called and intercepted! $(((Get-PSCallStack|select * | fl|out-string) |%{$_;"-----------------"}) -split '\n' -replace '\s*$' |?{$_} | %{"`n|`t$_"} )"
    return $null
}

Function Get-ResponseAuthentication_WS {
    $HostNameFromURL = $request.url -replace '^\w*://' -replace ':.*'
    $CookieName = "PSWSebService"
    $AuthHeader = $request.HEADERS['Authorization']
    $context.response.HEADERS.add('Authorization',$AuthHeader)
    $Cookie = $request.cookies[$CookieName]
    $context.response.cookies.add($Cookie)
    Write-Host $PSScriptRoot
    if ($null -eq $Cookie) {
        Set-ResponseAuthentication_WS -CookieName $CookieName
        #$Cookie = $request.Cookies[$CookieName]
    }
    $ParseJWT=Parse-JWTtoken -token $Cookie.Value
    [ordered]@{
        HostName=$HostNameFromURL
        CookieName=$Cookie.Name
        CookieValue=$Cookie.Value
        Cookie=$Cookie
        ParseJWT=$ParseJWT
        WebUserProfile=''
        AuthHeader=$AuthHeader
    }
}



Function Set-ResponseAuthentication_WS {
    param (
        $CookieName = "PSWSebService",
        $HostName,
        $UserName = 'Anonymous',
        [securestring]$password,
        $Name,
        $Expires = (get-date).addminutes(30)
    )
    $Groups = @()
    $Cred = [pscredential]::new($UserName,$password)
    
    if (
        ($Cred.GetNetworkCredential().password | 
        ?{$_ -match '\S'} )
    )
    {
        
        return (
            [pscustomobject]@{
                source='form';
                error='Invalid password'
            }
        )
    }
    if ($UserName -eq 'anonymous') {
        $Test = $null
    }
    else {
        $test = Test-Cred_WS -Credentials $Cred
    }
    switch ($test) {
        'Authenticated' {
            $WebUserProfile = Get-WebUserProfile_WS -Username $UserName
        }
        'Not Authenticated' {
            $context.response.statuscode = 404
        }
    }
    $Cert=(Get-JWTCertificate ).certificate
    $JWTClaim = New-JWTClaim -Subject $UserName -Name $Name -Issuer ($Cert.name + 'api/v1/auth') -ValidforSeconds (30 * 60) -GroupNames ($Roles|?{$_}|%{$_.Group})
    $jwt = New-Jwt -PayloadJson $JWTClaim -Cert $Cert 
    $Cookie = [System.Net.Cookie]::new()
    $Cookie.Name = $CookieName
    $Cookie.Secure = $true
    $Cookie.HttpOnly = $true
    $Cookie.Expires = $Expires
    $Cookie.Value = $jwt
    $Cookie.Domain = $HostName
    $context.response.cookies.add($Cookie)
    $context.response.HEADERS.add('Authorization',"Bearer $jwt")
}

Function Get-WebUserProfile_WS {
    param (
        $Username
    )
    $Membership = @{}
    $Domain = ($UserName -split '\\' |select -First 1) -split '@' | select -Last 1
    $UName = ($UserName -split '\\' |select -last 1) -split '@' | select -First 1
    if ($Username -eq $UName) {$Domain = 'localhost'}
    $ADuser = Get-ADUser -Server $Domain -AuthType Negotiate -Credential $Cred -Identity $UName -Properties memberof
    $Membership.Add("$domain\$uname",$true)
    $ADuser.MemberOf -replace ',.*' -replace '^cn=' | %{$Membership.Add("$Domain\$_",$true)}
    $Roles=import-csv "$Global:Project_Root\ACL" -Delimiter "`t" | Where-Object {$Membership.Contains($_.Name)}            
    $LocalGroups = Get-LocalGroup | Get-LocalGroupMember | Where-Object {$Membership.Contains($_.Name)}
    $WebUserProfilePath = "$Global:Project_Root\home\$Domain\$UName"
    [pscustomobject]@{
        WebUserProfilePath=$WebUserProfilePath
        LocalGroups=$LocalGroups
        Roles=$Roles
        ADUser=$ADuser
        Membership=$Membership
    }

}