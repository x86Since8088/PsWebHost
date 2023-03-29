Function IsUserMemberOf {
    param(
        $UserName = $global:context.User.Identity.Name,
        [string[]]$GroupCN,
        $Searchon
    )
    if ($UserName -match "@") 
    {
        if (-not $Searchon) {$Searchon = 'userprincipalname'}
    }
    ELSEif ($UserName -match "\\") 
    {
        $UserName = $UserName -split '\\' | Select-Object -First 1 -Skip 1
        if (-not $Searchon) {$Searchon = 'samaccountname'}
    }
    ELSE 
    {
        if (-not $Searchon) {$Searchon = 'samaccountname'}
    }
    GetGroupMembership -Name $UserName -Searchon $Searchon |?{$_} | ?{$DN = $_;$N = $_ -replace '^CN=([^,]+).+$','$1'; $GroupCN| ?{($_ -eq $N) -or ($_ -eq $DN)}}
}
