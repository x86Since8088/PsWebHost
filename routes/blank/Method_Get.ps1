param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/text'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 0
return ""
#Authentication = 'Anonymous'