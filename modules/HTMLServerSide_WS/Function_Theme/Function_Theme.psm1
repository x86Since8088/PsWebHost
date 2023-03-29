

    Function Get_Theme {
        param (
            [string]$Name = 'Blue1_SideMenu_Accd1',
            $Type
        )
        Get-ChildItem "$Global:Project_Root\wwwroot\css" "Theme_$Name" | 
        Where-object{$_.psiscontainer} |
        Select-Object -First 1 | 
        ForEach-Object{
            Get-ChildItem $_.FULLNAME | Where-object{-not ($_.fullpath -match '\\archive\\| \- copy\.')} | Where-object{
                ($_.name -split '\.')[-1] -eq $Type
            } | ForEach-Object{
                $File = $_
                $WebPath = $File.FullName.replace("$Global:Project_Root\wwwroot\",'').replace('\','/')
                switch ($Type)
                {
                    'js' {
                        Write_Tag -Tag Script -TagData "SRC=""/$WebPath"" type='application/x-javascript'" 
                    }
                    'css' {
                        Write_Tag -Tag link -TagData "rel='stylesheet' type='text/css' href='/$WebPath'"
                    }
                    'HTMLMenu' {
                        & "$Global:Project_Root\Apps\Menu\Menu.ps1"
                    }
                    default {Get-Content $File.FULLNAME }
                }
            }
        }
    }

    Function Update_Theme {
        param (
            [string]$Name='Blue1_SideMenu_Accd1'
        )
        [array]$Global:Include_Java = Get_Theme -Name $Name -Type js
        [array]$Global:Include_CSS = Get_Theme -Name $Name -Type css
        [array]$Global:Include_HTML_Menu = Get_Theme -Name $Name -Type HTMLMenu 
        [array]$Global:Include_HTML_Header = Get_Theme -Name $Name -Type HTMLHeader
        [array]$Global:Include_HTML_Footer = Get_Theme -Name $Name -Type HTMLFooter
        [array]$Global:Include_HTML_Navigation = Get_Theme -Name $Name -Type HTMLNavigation
    }

