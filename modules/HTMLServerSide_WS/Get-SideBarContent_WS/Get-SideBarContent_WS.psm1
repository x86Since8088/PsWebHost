Function Get-SideBarContent_WS {
    Write-Warning 'Get-SideBarContent_WS is still under development.'
    Get-Logo_WS
    $Cookie=$context.request.cookies['PSWSebService']  2> $null
    $context.response.cookies.add($Cookie)
    $SessionCookieData=Get-ResponseAuthentication_WS 2> $null
    
@'
    <div id="WebUserProfileIcon">
        <span>
        <img id="WebUserProfileIconImage"/ src="/img/WebUserProfile_default.png">
        <div ID="UserName"></Div>
        <span>
    </div>
    <a href="#">About</a>
    <a href="#">Services</a>
    <a href="#">Clients</a>
    <a href="#">Contact</a>
'@
}