#Name = "/process"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 1
$Data = Get-WmiObject win32_process -Property * | ConvertTo-Html
return $Data