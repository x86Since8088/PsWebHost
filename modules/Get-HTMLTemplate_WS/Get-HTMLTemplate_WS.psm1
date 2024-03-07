Function Get-HTMLTemplate_WS ([string]$Path = "$($Global:PSWebServer.Project_Root.Path)\Routes") {
    $Ptext = $Path
    do {
        if (test-path "$Ptext\template.html") {
            return "$Ptext\template.html"
        }
        else {
            $Ptext = split-path $Ptext
        }
    }
    until ($Ptext -eq '')
}