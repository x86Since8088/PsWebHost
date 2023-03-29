param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
$Response=$SessionObject.context.response
#Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 300
#'301 Moved Permanently'
$response.statusCode=301
$response.AddHeader("Location","/Home")
