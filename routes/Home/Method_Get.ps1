#Name = "/Home"
#Authentication = 'Anonymous'
param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 10
$ThisFolder=split-path $MyInvocation.MyCommand.Definition
return ([system.io.file]::ReadAllText("$ThisFolder\Template.html"))
