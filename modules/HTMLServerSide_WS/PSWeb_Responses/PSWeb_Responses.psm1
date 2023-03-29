Function Response_PageNotFound_404 {
    param(
        $SessionObject=(Get-WebhostSessionObject)
    )
    $SessionObject.context.response.statuscode=[System.Net.HttpStatusCode]::NotFound
    _H1 -innerHTML "404 - What????"
    "It's not you, it's me.  The page you are looking for cannot be found."
    Get-WebHostPSCallStackText -Skip 1 -First 3
    ''
    $Context | Convertto-DOM
    ''
    $Response| Convertto-DOM
    ''
    $Global:UserSessionTable| Convertto-DOM
    ''
}