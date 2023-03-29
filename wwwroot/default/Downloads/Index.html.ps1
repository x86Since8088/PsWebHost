$PagePath = $MyInvocation.MyCommand.Definition
$Pagefolder = split-path $MyInvocation.MyCommand.Definition
Function TreeMe {
    param ($Path,
        [switch]$Continue
    )
    if (-not $Continue)
    {
        _ul -innerHTML (.{
            . TreeMe -Continue -Path $Path
        })
    }
    ELSE
    {
        gci $Path | %{
            if ($_.PSIscontainer)
            {
                _li -innerHTML (.{
                    $_.Fullname.replace($Global:ScriptFolder,'')
                    & TreeMe -Path $_.FullName -Continue
                })
            }
            ELSE
            {
                _li -innerHTML (.{
                    _A -TagData "href='$($_.Fullname.replace($Global:ScriptFolder,'') )'" -innerHTML $_.FullName.replace($Global:ScriptFolder,'')
                })
            }
        }
    }
}

gci $Pagefolder |?{$_}|%{
    $RP = $_.fullname.replace($global:ScriptFolder,'')
    _a -TagData "href=$RP" -innerHTML (
        $RP
    )
}