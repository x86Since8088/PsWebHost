    Function Set_CacheControl {
        param (
            [ValidateSet('public','private','no-cache','no-store')]
            $Policy='private',
            [int]$MaxAge=60
        )
        #http://condor.depaul.edu/dmumaugh/readings/handouts/SE435/HTTP/node24.html
        $Item = "$Policy, max-age=$MaxAge"
        $global:context.response.AddHeader("Cache-Control", $Item)
        $global:context.response.Headers.Item("Cache-Control") = $Item
    }
