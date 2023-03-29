Function HTMLCurly {
<#
.Synopsis
Create html tags using less quote escaping by using scriptblocks.
.Description
-ExecuteInnerHTML must be provided if you want to run the -InnerHTML scriptblock 
as powershell code.  Othersise the text value will be used.
#>
    param (
        [string]$Name,
        [scriptblock]$TagData,
        [scriptblock]$InnerHTML,
        [switch]$ExecuteInnerHTML
    )
    $text = '<'+$Name
    if ($NULL -eq $TagData) {}
    ELSEif ($TagData.ToString().Length -ne 0) {
        $text+=' '+$TagData.ToString()
    }
    $text+='>' 
    if ($ExecuteInnerHTML) {
        . $InnerHTML | %{$text+="$_`n"}
    }
    else {
        $text+= $InnerHTML.ToString()
    }
    $text+="</$name>"
    return $text
}