    function Get-GoogleCSEQueryString {
        #http://www.powershelladmin.com/wiki/Accessing_the_Google_Custom_Search_API_using_PowerShell#Requirements
        param([string[]] $Query)
        #Add-Type -AssemblyName System.Web # To get UrlEncode()
        $QueryString = ($Query | %{ [Web.HttpUtility]::UrlEncode($_)}) -join '+'
        # Return the query string
        $QueryString
    }
    
    Function Search_GoogleAPIsCustomSearch {
        param (
            $SearchString = 'inurl:"/events/"'
        )
        $QueryString = Get-GoogleCSEQueryString $SearchString
        $Uri = "https://www.googleapis.com/customsearch/v1?key=$GoogleCSEAPIKey&cx=$GoogleCSEIdentifier&q=$QueryString"
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$false
        $WC.Headers.Add("user-agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)")
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $wc.DownloadString($Uri)
    }

    Function Search_Google {
        param (
            $SearchString = 'inurl:"/events/"'
        )
        $QueryString = Get-GoogleCSEQueryString $SearchString
        $Uri = "https://www.google.com/#q=$QueryString"
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$false
        $WC.Headers.Add("user-agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)")
        #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $wc.DownloadString($Uri)
    }
   
