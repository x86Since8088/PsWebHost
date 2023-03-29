param (
    $context=$Global:context
)
[Reflection.Assembly]::LoadWithPartialName('System.Web') > $null
cls
#GET /debug
    $Request = $context.request
    # get post data.
    $data = extract $request
    write-host Post Data: (($data | out-string) -replace '\s\s*$' -replace '\n\n',"`n")
    # get the submitted name.
    $Command = $data.item('Command')
    $CommandDecoded = Decode-URL_WS $Command
    $CommandsHT = [ordered]@{}
    $data.command | %{[System.Web.HttpUtility]::UrlDecode($_)} | %{
        write-host "------------`nRunning $_"
        if ($null -ne $_) {
            $CommandsHT.add($_,((. ([scriptblock]::Create($_))) 2>&1 3>&1 4>&1 5>&1 6>&1|%{Convert-ObjectToHTMLTable -InputObject $_ -AS LIST} ))
        }
    }
    write-host Post Data: (($CommandsHT | fl | out-string) -replace '\s\s*$' -replace '\n\n',"`n")
    
    # render the 'FormResponse' snippet, passing the name.
    $Form = Get-Content ((Split-Path $MyInvocation.MyCommand.Definition) +'\Form.html')
    $Myresponse = HTMLCurly div -ExecuteInnerHTML -TagData {id="myresponse"} -InnerHTML {
        '<title>Debug</title>'
        $Form
        '<h1>Form Response</h1>'
        '<h2>Command</h2>' + $CommandDecoded
        '<div style="font-family: ""Lucida Console"", Monaco, monospace">' 
        '<h2>Output</h2>' + $CommandDecoded + "`n" + 
        ($CommandsHT.keys | %{$Key=$_;$CommandsHT[$key]})
        #Convert-ObjectToHTMLTable -InputObject $CommandsHT -AS LIST
        '</div>' 

        if ($data['IncludeResponse'] -eq 'Checked') {
            '<H1>Debug</h1>'
            (Convert-ObjectToHTMLTable -VariableName Request  -InputObject $Request -as List)
        }
        if ($data['IncludeCookie'] -eq 'Checked') {
            '<H1>Cookie Data</h1>'
            $SessionCookieData=Get-ResponseAuthentication_WS
            (Convert-ObjectToHTMLTable -VariableName SessionCookieData  -InputObject $SessionCookieData -as List)
        }
        if ($data['IncludeErrors'] -eq 'Checked') {

            "<h1>`$Error Output</h1>"
            $i=0
            $Error | %{'<HR>';Convert-ObjectToHTMLTable -VariableName "Error[$i]" -InputObject $_ -AS LIST;$i++}
            $Error.Clear()
        }
    }

    #$page = render $Myresponse @{name = $name}
    $page = $Myresponse

    # embed the snippet into the template.
    return (render (Get-Content (Get-HTMLTemplate_WS)) $page)

      