Function Set_CacheControl {
    param (
        $SessionObject=(Get-WebhostSessionObject),
        [ValidateSet('public','private','no-cache','no-store')]
        $Policy='private',
        [int]$MaxAge=60
    )
    #http://condor.depaul.edu/dmumaugh/readings/handouts/SE435/HTTP/node24.html
    $Item = "$Policy, max-age=$MaxAge"
    $response=$SessionObject.context.response
    if ($null -eq $SessionObject) {
        write-warning "Set_CacheControl has an empty `$SessionObject : $(Get-PSCallStack|Out-String|%{"`n|`t$_"})"
    }
    ELSE {
        $response.AddHeader("Cache-Control", $Item)
        $response.Headers.Item("Cache-Control") = $Item
    }
}

