param ($SessionObject=(Get-WebhostSessionObject))
$SessionObject.context.response.ContentType='text/html'
Set_CacheControl -SessionObject $SessionObject -Policy private -MaxAge 10
$Data = Launch_Application -Path ($Global:Project_Apps + '\' + $SessionObject.context.Request.Url.LocalPath)
return $Data

#    Authentication = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication

