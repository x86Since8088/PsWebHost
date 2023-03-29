#Name = "/favicon.ico"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='application/octet-stream'
Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 300
[byte[]]$Data = get-content -Encoding byte ("$Global:Project_Root\wwwroot" + ([Web.HttpUtility]::UrlDecode($SessionObject.LocPath) -replace '\/','\'))
return $Data
