#Name = "/content"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='application/octet-stream'
if ($null -eq $SessionObject) {
    Write-Error -Message 'No -SessionObject';
    $Data = Get-PSCallStack;
    return $Data
}
[string]$ReadPath="$Global:Project_Root\wwwroot" + ([Web.HttpUtility]::UrlDecode($SessionObject.LocPath) -replace '\/','\')
$GI = Get-Item -LiteralPath $ReadPath
if ($ReadPath -like "*\index.html.ps1")
{
    Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 0
    $Data = Launch_Application -Path $ReadPath
    return $Data
}
elseif (Test-Path -LiteralPath "$ReadPath\index.html.ps1")
{
    Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 30
    $Data=Launch_Application -Path "$ReadPath\index.html.ps1"
    return $Data
}
ELSEif (($null -ne $GI) -and -not $GI.psiscontainer)
{
    Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 30
    [byte[]]$Data=get-content -encoding Byte $ReadPath
    return $Data
}
ELSE
{
    $SessionObject.context.response.StatusCode = 404
    _H1 -innerHTML (
        "404 - The Princess is in another castle..."
    )
}
