#Name = "/Menu"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 0
$Data = Launch_Application
return $Data