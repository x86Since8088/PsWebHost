#Name = "/data"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='application/octet-stream'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 10
$Data = Launch_Application
return $Data

