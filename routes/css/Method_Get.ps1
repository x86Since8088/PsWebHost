#Name = "/css"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/css'
Set_CacheControl -SessionObject $SessionObject -Policy public -MaxAge 300
[byte[]]$Data = get-content -encoding Byte ("$Global:Project_Root\wwwroot" + ([Web.HttpUtility]::UrlDecode($SessionObject.LocPath) -replace '\/','\'))
return $Data
