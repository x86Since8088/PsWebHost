param (
    $HTTPSListenerContext,
    [switch]$GetApprovedArgs,
    $AppArguments
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
$Error.clear()
$Path_ControlPannel = split-path -LiteralPath $MyInvocation.MyCommand.Definition
#$principal = new-object System.Security.principal.windowsprincipal($global:context.User.Identity)
if($Global:Win32_ComputerSystem.OEMLogoBitmap)
{
    $BitmapBase64 = [convert]::ToBase64String($Global:Win32_ComputerSystem.OEMLogoBitmap)
    $Img = "<img src='data:image/bmp;base64,"+$BitmapBase64+"' alt='Embeded Image'/>"
}
ELSE
{
    $IMG = ""
}
if ("$Env:USERDOMAIN\$env:UserName" -ne $global:context.User.Identity.Name)
{
    return "Unauthorized.  This tool instance belongs to another User"
}
write_tag -Tag "div" -TagData "class='Logo'" -Content (
    $Img + (. {
        Write_Tag -Tag "div" -TagData "class='title'" -Content ('AdminConsole')
        Write_Tag -Tag "div" -TagData "class='subtitle'" -Content ('Welcome ' + $global:context.User.Identity.Name + '!  You have been authenticated.')
    })
)
$Commands_ControlPannel = Get-ChildItem "$Path_ControlPannel\ControlPannel\Commands" *.ps1 -Recurse | ?{-not $_.psiscontainer} | select @{n='Folder';e={$_.Directory.fullname.replace("$Path_ControlPannel\ControlPannel\Commands\",'')}},@{n='Name';e={$_.name.replace('.ps1','')}}
if (-not $Params) {$Params = @{}}
if ($AppArguments)
{
    $ParamName = $AppArguments | ?{$_.Name -eq 'ParamName'}
    $AppArguments | %{
        $AppArgumentItem = $_
        if ($_.name -eq 'App')
        {
            if ($_.Value -eq 'ControlPannel')
            {
                Write_Tag -Tag h2 -Content 'Folders'
                $Commands_ControlPannel | Group-Object Folder | %{
                    #Name now means the name of the group.
                    Write_Tag -Tag h3 -Content $_.Name 
                    $_.group | %{
                        #$_.Name now means the name of the file.

                        Write_Tag -Tag A -TagData "href='/home?App=ControlPannel?Command=$($_.name)'" -Content $_.name
                        Write_Tag -Tag BR
                    }
                }
            }
        }
        if ($_.name -eq "Navigate")
        {
            
        }
        if ($_.name -eq "ParamReset")
        {
            $Params = @{}
        }
        if ($_.name -eq "ParamAdd")
        {
            if (-not $ParamName)
            {
                'ParamAdd passed without ParamName.'
            }
            ELSE
            {
                [array]$V = $Params.($ParamName)
                $V = $V + $_.Value
                if ($params.Contains($ParamName))
                {
                    $params.Remove($ParamName)
                }
                $Params.Add($ParamName,$V)
            }
        }
        if ($_.name -eq "ParamRemove")
        {
            {
                'ParamAdd passed without ParamName.'
            }
            ELSE
            {
                [array]$V = $Params.($ParamName)
                $RV = $_.Value
                $V = $V | ?{$_ -ne $RV}
                if ($params.Contains($ParamName))
                {
                    $params.Remove($ParamName)
                }
                $Params.Add($ParamName,$V)
            }
        }
        if ($_.name -eq "Command")
        {
            if ($_.value -eq "quit")
            {
                LastCall
            }
            ELSE
            {
                $Commands_ControlPannel | ?{$_.Name -eq $AppArgumentItem.Value} | %{
                    gci -LiteralPath "$Path_ControlPannel\ControlPannel\Commands\$($_.Folder)" -Filter "$($_.Name).ps1" | %{
                        (get-command $_.FullName).Parameters | ?{$_.key} | %{
                            $ParamItem = $_
                            if (-not $Params.Contains($ParamItem.Values.name))
                            {
                                $Params.Add($ParamItem.Values.name,
                                    (
                                        Get-Variable $ParamItem.Values.name
                                    ).Value
                                )
                            }
                        }
                        Write_Tag -Tag 'B'  -Content 'Running command...'
                        $Command = ([string]$_.FullName).replace($ScriptPath,'/')
                        write_table -Inputobject ($Params | select @{Name='Command';Expression={}},* -ErrorAction SilentlyContinue)
                        & $_.FullName @Params
                    }
                }
            }
        }
    }
}

if ($Error)
{
    '<H1>Errors</H1>'   
    $Error
}