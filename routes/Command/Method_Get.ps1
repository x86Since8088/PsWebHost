param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 0
$response.statusCode=200
return (.{

$SessionObject | ConvertTo-dom  
})
#Authentication = 'Anonymous'
