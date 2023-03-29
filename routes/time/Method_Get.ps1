#Name = "/time"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 0
$Data=get-date|out-string
return $Data