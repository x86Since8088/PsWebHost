[Reflection.Assembly]::LoadWithPartialName('System.Web') > $null
Function Decode-HTML_WS {
    param ($String)
    [System.Web.HttpUtility]::HtmlDecode($String)
}

Function Encode-HTML_WS {
    param ($String)
    [System.Web.HttpUtility]::HtmlEncode($String)
}

Function Decode-URL_WS {
    param ($String)
    [System.Web.HttpUtility]::UrlDecode($String)
}

Function Encode-URL_WS {
    param ($String)
    [System.Web.HttpUtility]::UrlEncode($String)
}