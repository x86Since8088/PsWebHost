﻿    Function Convert-ObjectToHTMLTable {
        param (
            $TagData,
            [string]$VariableName = 'Variable',
            [string]$Scope=2,
            $InputObject=(Get-Variable -Name $VariableName -Scope $Scope),
            [string[]]$Property,
            [hashtable]$ExpandPropertyHashtable=@{},
            [validateset('TABLE','LIST','TEXT')][string]$AS = 'Table',
            [int]$MaxDepth=2,
            [int]$RecursionLevel=0,
            [validateset('DeepTable','Table')][string]$OutputStyle = 'DeepTable'
        )
        if ($null -eq $InputObject) {
            return
        }
        if ('' -eq $InputObject) {
            return
        }
        #Handle Hastable-like objects keys if available.
        [array]$DetectedProperties = @()
        if ($null -ne $InputObject.Keys) {
            if ($InputObject.keys.gettype().name -match 'Key.*?Collection') {
                $DetectedProperties = $InputObject.Keys
            }
        }
        #Handle objects properties if available.
        if ($DetectedProperties.count -eq 0) {
            $SingleInstanceHT = @{}
            [array]$DetectedPropertyObjects = $InputObject | 
                select -First 10 -Last 10 | 
                Where-Object{$_}|
                Foreach-Object{$_.psobject.Properties} | 
                Where-Object{-not $SingleInstanceHT.Contains($_.Name)}|
                ForEach-Object{$SingleInstanceHT.add($_.name,$True);$_}
            if ($DetectedPropertyObjects.count -eq 1) {
                if ($DetectedPropertyObjects[0].name -eq 'Length') {
                    return "<p>$InputObject</p>"
                }
            }
            $DetectedProperties = $DetectedPropertyObjects.name
        }
        #Catch unhandled instances where keys are used, but they are not the expected type.
        if ($DetectedProperties.count -eq 0) {$DetectedProperties = $InputObject.Keys}
        if ($property.count -eq 0) {
            $Property = $DetectedProperties
        }
        elseif ($DetectedProperties.count -gt 1) {
            $Property = $DetectedProperties.name
        }
        Function MakeTable {
            param (
                $InputObject=$InputObject,
                $TagData=$TagData,
                $VariableName=$VariableName,
                [string[]]$Property=$Property,
                [hashtable]$ExpandPropertyHashtable=$ExpandPropertyHashtable,
                [string]$AS=$AS,
                [int]$MaxDepth=$MaxDepth,
                $OutputStyle=$OutputStyle
            )
            IF ($null -eq $TagData) {}
            elseif ($TagData.gettype.name -like 'string*') {
                $TagData=@{
                    Table=$TagData -join ' '
                }
            }
            $Keys = $ExpandPropertyHashtable.Keys | ?{$null -ne $_}
            $Keys | ?{try{$ExpandPropertyHashtable[$_].GetType().name -ne 'scriptblock'} catch {$true}} | 
            ForEach-Object{
                $ExpandPropertyHashtable.Remove($_)
                Write-Error -Message "-ExpandPropertyHashtable must be a hastable of scriptblocks to transform specific parameters."
            }
            $SingleInstance=@{}
            if ($Property.count -eq 0) {
                $InputObject | Select -first 5 -last 5 | ForEach-Object{
                    $InputObjectItem=$_
                    $InputObjectItem.psobject.Property.name | ?{$_} | 
                    Where-Object{-not $SingleInstance.contains($_)}|
                    ForEach-Object{$Property+=$_;$SingleInstance.add($_,$True)}
                }
            }
            $Output = HTMLCurly div -ExecuteInnerHTML -InnerHTML {
                '<p>['+$InputObject.gettype().name+']'+$VariableName+'</p>'
                $Seed=(get-date -f 'mmss')
                $UniqueID=$Seed+(Get-Random -SetSeed $Seed)
                 '<input id="'+$uniqueID+'" onkeyup="SearchTable(this.id)" placeholder="Search..."/>'
                switch ($OutputStyle) {
                    'table' {
                        [string]$Table = ($InputObject | convertto-html -Property $Property -As $AS -Fragment) -join "`n"
                        $TagData.Keys | ?{$_} | %{
                            $Table=$Table -replace "\<$_(\W)","<$_ $($TagData[$_]) `$1"
                        }
                        $Table=$Table -replace '^\<Table',"<Table  id=""Table$uniqueID"" title=""$VariableName"""
                        $Table
                    }
                    'deeptable' {
                        HTMLCurly div -TagData {style="overflow-x:auto"} -ExecuteInnerHTML -InnerHTML {
                            if ($as -eq 'list') {
                                '<table id="Table'+$uniqueID+'" title="$VariableName">'
                                foreach ($InputObjectItem in $InputObject) {
                                    '<col/><col/>'
                                    foreach ($PropertyItem in $Property) {
                                        '<tr><td class="tr_list_head"><div style="overflow-x:none">'+ $PropertyItem+'</div></td><td>'
                                        $ExpandPropertyHashtableMatch=$ExpandPropertyHashtable[$PropertyItem]
                                        HTMLCurly -ExecuteInnerHTML -Name div -TagData {style="overflow-x:auto"} -InnerHTML {
                                            if ($null -eq $ExpandPropertyHashtableMatch) {
                                                if ($RecursionLevel -ge $MaxDepth) {
                                                    $InputObjectItem.($PropertyItem)
                                                }
                                                else {
                                                    $InputObjectItem.($PropertyItem) |Where-Object{$_ -match '\w'}| %{
                                                        Convert-ObjectToHTMLTable -InputObject $_ -AS LIST -MaxDepth $MaxDepth -RecursionLevel ($RecursionLevel + 1) -VariableName "$VariableName.$PropertyItem"
                                                    }
                                                }
                                            }
                                            else {
                                                (($InputObjectItem.($PropertyItem)|Foreach-Object $ExpandPropertyHashtable[$PropertyItem] | out-string) -replace '\s\s*(\n)','$1' -replace '\n\s*\n\s*\n*',"`n" )
                                            }
                                        }
                                        '</td></tr>'
                                    }
                                }
                                '</table>'            
                            }
                            else
                            {
                                '<table id="Table'+$uniqueID+'" title="$VariableName">' 
                                '<tr>'+($Property | %{'<th>'+$_+'</th>'}) +'</tr>' 
                                '<tr>'+($Property | %{'</col>'})+'</tr>' 
                                foreach ($InputObjectItem in $InputObject) {
                                    '<tr>'+(
                                        $Property | %{
                                            $ExpandPropertyHashtableMatch=$ExpandPropertyHashtable[$_]
                                            if ($null -eq $ExpandPropertyHashtableMatch) {
                                                '<td>'+$InputObjectItem.($_)+'</td>'
                                            }
                                            else {
                                                '<td>'+ (($InputObjectItem.($_)|Foreach-Object $ExpandPropertyHashtable[$_] | out-string) -replace '\s\s*(\n)','$1' -replace '\n\n\n*',"`n" ) + '</td>'
                                            }
                                        }
                                    ) + '</tr>'
                                }
                                '</table>'
                            }
                        }
                    }
                    'text' {
                        switch ($as) {
                            'TABLE' {$InputObject | select $Property | Format-Table -AutoSize -Wrap | out-string}
                            'LIST'  {$InputObject | select $Property | Format-List | out-string}
                        }
                    }
                }
            }
            return $Output
        }
        $TypeName = $InputObject.gettype().name
        if ($null -eq $InputObject)                  {return}
        if ($Property.Count -eq 0)                   {return (($InputObject -split '\n\n*' |?{$_ -match '\S'}|%{"<p>$_</p>"}) -join "`n")}
        if ($InputObject    -is [datetime])          {return $InputObject.tostring()}
        if ($InputObject    -is [timespan])          {return $InputObject.tostring()}
        if ($TypeName       -eq 'TimeOfDay')         {return $InputObject.tostring()}
        if ($TypeName       -eq 'IPADDRESS')         {return $InputObject.IPAddressToString}
        if ($TypeName       -match '^string')        {return ($InputObject -split '\n\n*'  |?{$_ -match '\S'}|%{"<p>$_</p>"})}
        if ($InputObject    -is [valuetype]) {return ($InputObject -split '\n\n*' -join ", "|%{"<p>$_</p>"})}
        if ($Property.Count -gt 1)                   {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($TypeName       -eq 'hashtable')         {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($TypeName       -eq 'psobject')          {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($InputObject    -is [object])            {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($InputObject    -is [hashtable])         {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($TypeName       -eq 'object[]')          {return (MakeTable -InputObject $InputObject -Property $Property)}
        if ($TypeName       -eq 'Object')            {return (MakeTable -InputObject $InputObject -Property $Property)}
        return (MakeTable -InputObject $InputObject)
    }
