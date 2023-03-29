#Name = "/reload"
#ToDo Require auth
#Authentication = 'Anonymous' 
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Remove-Module *
$Response=$SessionObject.context.response
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 0
#'301 Moved Permanently'
$response.statusCode=200
#$response.AddHeader("Location","/Home")
$Data=. {
    . LoadFunctions -verbose *>&1 | ConvertTo-Xml
    . ReLoadFunctions_Start 2>&1 3>&1 4>&1 5>&1 6>&1 | ConvertTo-Xml
    . "$Global:Project_Root\Scripts\Router.ps1"
}
return $Data