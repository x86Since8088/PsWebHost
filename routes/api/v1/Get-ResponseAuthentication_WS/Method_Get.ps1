$JWT = Get-ResponseAuthentication_WS  
$WebUserProfile = get-WebUserProfile_ws
@{
    Token = $JWT
    Actions = 'logoff','logon'
    Roles = $WebUserProfile.roles
    WebUserProfile = $WebUserProfile
} | ConvertTo-Json