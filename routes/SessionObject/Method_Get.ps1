#Name='/SessionObject'
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 60
$response.statusCode=200
$SessionObject | ConvertTo-Html
''
$SessionObject.UserSession | ConvertTo-Html
''
$SessionObject.WebRequest | ConvertTo-Html