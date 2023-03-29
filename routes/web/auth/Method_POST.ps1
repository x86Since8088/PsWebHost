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
    $CommandsHT = @{}
    $data.command | %{[System.Web.HttpUtility]::UrlDecode($_)} | %{
        write-host Running $_
        if ($null -ne $_) {
            $CommandsHT.add($_,(. ([scriptblock]::Create($_))))
        }
    }
    write-host Post Data: (($CommandsHT | fl | out-string) -replace '\s\s*$' -replace '\n\n',"`n")
    
    # render the 'FormResponse' snippet, passing the name.
    $Form = gc ((Split-Path $MyInvocation.MyCommand.Definition) +'\Form.html')
    $Myresponse+=$Form

    #Single line logon
    $page = render $Myresponse @{
        label = ''
        br = ''
        html = ''
    }

    # embed the snippet into the template.
    return (render $template $page)

      