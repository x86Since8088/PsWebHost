    function Get-GoogleCSEQueryString {
        #http://www.powershelladmin.com/wiki/Accessing_the_Google_Custom_Search_API_using_PowerShell#Requirements
        param([string[]] $Query)
        #Add-Type -AssemblyName System.Web # To get UrlEncode()
        $QueryString = ($Query | %{ [Web.HttpUtility]::UrlEncode($_)}) -join '+'
        # Return the query string
        $QueryString
    }