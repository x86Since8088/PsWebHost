    Function Convert-ObjectToHTMLTable {
        param (
            $TagData,
            [string]$VariableName = 'Variable',
            [string]$Scope=2,
            $InputObject=(Get-Variable -Name $VariableName -Scope $Scope),
            [string[]]$Property,
            [hashtable]$ExpandPropertyHashtable=@{},
            [validateset('TABLE','LIST')][string]$AS = 'Table'
        )
        Function MakeTable {
            param (
                $InputObject=$InputObject,
                $TagData=$TagData,
                $VariableName=$VariableName,
                [string[]]$Property=$Property,
                [hashtable]$ExpandPropertyHashtable=$ExpandPropertyHashtable,
                [string]$AS=$AS
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
            '<p>['+$InputObject.gettype().name+']'+$VariableName+'</p>'
            $Seed=(get-date -f 'mmss')
            $UniqueID=$Seed+(Get-Random -SetSeed $Seed)
            '<input id="'+$uniqueID+'" onkeyup="SearchTable(this.id)" placeholder="Search..."/>'
            [string]$Table = ($InputObject | convertto-html -Property $Property -As $AS -Fragment) -join "`n"
            $TagData.Keys | ?{$_} | %{
                $Table=$Table -replace "\<$_(\W)","<$_ $($TagData[$_]) `$1"
            }
            $Table=$Table -replace '^\<Table',"<Table  id=""Table$uniqueID"" title=""$VariableName"""
            $Table
            <#
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
            #>
        }
        $TypeName = $InputObject.gettype().name
        if ($null -eq $InputObject) {return}
      
        if ($TypeName -eq 'hashtable') {return (MakeTable -InputObject $InputObject -Property $InputObject.keys)}
        if ($TypeName -eq 'psobject')  {return (MakeTable -InputObject $InputObject)}
        if ($TypeName -eq 'Object[]')  {return (MakeTable -InputObject $InputObject)}
        if ($TypeName -eq 'Object')    {return (MakeTable -InputObject $InputObject)}
        if ($TypeName -match '^string|^int|^uint') {return ($InputObject|%{"<p>$_</p>"})}
        if ($PropNames.count -eq 1) {return "<p>$InputObject</p>"}
        return (MakeTable -InputObject $InputObject)
    }
