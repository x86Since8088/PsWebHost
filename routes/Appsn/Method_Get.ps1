$SessionObject.context.response.ContentType =  'text/html'
#CheckAuthentication -Role 
param ($SessionObject=(Get-WebhostSessionObject))
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 10
$Data = Launch_Application -Path ($Global:Project_Apps + '\' + $SessionObject.context.Request.Url.LocalPath)
return $Data
