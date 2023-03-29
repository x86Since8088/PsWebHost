Function ChunkedByType {
    param (
        [array]$InputObject
    )
    begin {
        [array]$Data=@()
        $Data+=$InputObject
        [string]$LastTypeString=''
        [string]$TypeString=''
        function Initprintit {
            if ($TypeString -ne '') {
                new-object psobject -property @{
                    TypeString=$LastTypeString
                    Data=$DataGroup
                    Headers=$Headers
                    Count=$DataGroup.Count
                    ChunkedByType=$True
                }
            }
            [array]$DataGroup=@()
            [hashtable]$HeaderHT=@{}
            [string[]]$Headers=@()
            [string]$LastTypeString=''
        }
        
        function printit {
            param (
                [array]$Data
            )
            . Initprintit
            foreach ($DataItem in $Data) {
                if ($Null -eq $DataItem) {
                    $Typestring='Null'
                }
                elseif ($DataItem.count -eq 0) {}
                else {
                    [string]$TypeString = ''
                    try{$Typeitem=$DataItem.gettype()}catch{$Typeitem=$null}
                    do {
                        $TypeString+=($Typeitem.name+',');
                        $Typeitem=$Typeitem.basetype
                    }
                    until ($Null -eq $Typeitem)
                    if ($TypeString -ne $LastTypeString) {
                        . Initprintit
                        $LastTypeString=$TypeString
                    }
                    $DataGroup += $DataItem
                    try {[array]$HeadersGroup= $DataItem.Keys |Where-Object{$_}| Where-Object{$_.gettype().name -match 'Collection'}}
                    catch {
                        [array]$HeadersGroup=@()
                    }
                    if ($HeadersGroup.count -eq 0) {
                        $HeadersGroup = $DataItem.psobject.Properties.name | Where-Object{$_}
                    }
                    $Headers += $HeadersGroup | Where-object{$null -eq $HeaderHT[$_]} | Foreach-object{$_;$HeaderHT.add($_,$True)}
                }
            }
            . Initprintit
        }
    }
    process {
        if ($Null -eq $_) {$LastType='null'}
        else {
            $Data+=$_
        }
    }
    end {
        printit -Data $Data
    }    
}



Function Convertto-DOM {
    param (
        [array]$InputObject,
        [switch]$GroupByType,
        [int]$Maxdepth=2,
        [int]$Depth=1,
        [switch]$HorizontalTables
    )
    begin {
        [array]$Data=@()
        [array]$DataI=@()
        if ($InputObject.count -eq 0) {}
        elseif ($InputObject[0] -eq $null) {
            [array]$DataI=$InputObject | Where-object{$null -ne $_} | ChunkedByType
        }
        elseif ($InputObject[0].ChunkedByType) {
            [array]$Datai=$InputObject | Where-object{$null -ne $_}
        }
        ELSE {
            [array]$Datai=$InputObject | Where-object{$null -ne $_} | ChunkedByType
        }
            Function ReturnDataByType {
                switch -regex ($DataItem.typestring) {
                    'null'  {}
                    '^u{0,1}Int' {
                        return (
                            html -TagName P -InnerHTML ([System.Web.HttpUtility]::HtmlEncode(($DataItem.data -join ', ')))
                        )
                        
                    }
                    'float' {
                        Return (
                            html -TagName P -InnerHTML ([System.Web.HttpUtility]::HtmlEncode(($DataItem.data -join ', ')))
                        )
                    }
                    'string' {
                        return (
                            ($DataItem.data | Foreach-object{ 
                                if ($_ -notmatch '^\s*\<') {
                                    html -TagName P -InnerHTML ([System.Web.HttpUtility]::HtmlEncode($_))
                                }
                                else {
                                    $_
                                }
                            }) -replace '\n','<br>'
                        )
                    }
                    'GroupItem' {
                        return (
                            html -TagName Div -InnerHTML (.{
                                html -TagName h1 -innerHTML ([System.Web.HttpUtility]::HtmlEncode($DataItem.Data.Name))
                                html -TagName  -Inter (convertto-dom (ChunkedByType $DataItem.Data.group) -HorizontalTables:$HorizontalTables)
                            })
                        )
                    }
                    'object' {
                        return (
                            Convertto-DOMtable $DataItem -Depth $Depth -MaxDepth $MaxDepth -HorizontalTables:$HorizontalTables
                        )
                    }
                    'Hashtable' {
                        return Convertto-DOMHTable ($DataItem | Convertfrom-HashTable) -HorizontalTables:$HorizontalTables
                    }
                    default {
                        return ($DataItem.data | ConvertTo-Xml).OuterXml
                    }
                }
            }

    }
    process {
        if ($Null -ne $_) {$Data+=$_}
    }
    end {
        $Data=$DataI+($Data|ChunkedByType)
        if ($GroupByType) {
            $DataGroup=$Data|Group TypeString
            $DataObject=$DataGroup[0]
            $DataObject.Data  = $DataGroup.Data
            $DataObject.Count = $DataObject.Data.Count
            Remove-Variable DataObject -ea SilentlyContinue
            [array]$DataObject=$DataObject
        }
        foreach ($DataItem in $Data) {
            if ($null -eq $DataItem) {
                    '<p />'
            }
            else {
                . ReturnDataByType
            }
        }
        $Data=@()
    }
}

Function Convertfrom-HashTable {
    process {
        if ($Null -ne $_) {
            if ($_.gettype().name -match 'hashtable') {
                new-object psobject -property $_
            }
        }
        else {
            $_
        }
    }
}

Function Convertto-DOMtable {
    param (
        [array]$InputObject,
        [switch]$Horizontal,
        [switch]$Title,
        [switch]$Caption,
        [string[]]$Headers,
        [switch]$isHashtbable,
        [int]$MaxDepth=2,
        [int]$Depth=1,
        [switch]$NestTables,
        [switch]$HorizontalTables
    )
    begin {
        [array]$PipeData=@()
        Function Table {
            param (
                $Data,$Headers,
                $Title,$Caption,
                [switch]$isHashtbable=$isHashtbable,
                [int]$MaxDepth=$MaxDepth,
                [int]$Depth=$Depth,
                [switch]$NestTables=$NestTables
            )
            (.{'<table title="'+([System.Web.HttpUtility]::HtmlEncode($Title))+'">'
            '<caption>'+([System.Web.HttpUtility]::HtmlEncode($Caption))+'</caption>'
            '<tr>'+(
                $Headers|ForEach-Object{
                    '<th>'+([System.Web.HttpUtility]::HtmlEncode($_))+'</th>'
                }
            )+'</tr>'

            foreach ($DataItem in $Data) {
                    '<tr>'+(
                        $Headers|
                            ForEach-Object{
                                $HeadrerItem=$_
                                if ($isHashtbable) {
                                    $V = $DataItem[$HeadrerItem]
                                } ELSE {
                                    $V = $DataItem.($HeadrerItem)
                                }
                                if ($null -eq $V) {'<td></td>'}
                                else {
                                    '<td>'+($DataItem.($_)| .{
                                        if ($MaxDepth -le $Depth) {
                                            $V
                                        }
                                        elseif ($V.gettype().name -match 'int|string*') {
                                            $V
                                        }
                                        else {
                                            if ($NestTables) {
                                                Convertto-DOM -InputObject $V -Depth ($Depth+1)
                                            }
                                            else {
                                                (($V | Format-List|out-string) -replace '\s*$' -split '\s*\n\s*' |Where-Object{$_}) -join '<br>'
                                            }
                                        }
                                    }) +'</td>'
                                }
                            }
                    )+'</tr>'
            }
            '</table>'})  -replace '\n','<br>'
        }
    }
    process {
        $PipeData+=$_ 
    }
    end {
        $PipeData=$InputObject+$PipeData
        if (
            ($InputObject.ChunkedByType)
        ) 
        {
            foreach ($PipeDataItem in $PipeData) {
                $Data=$PipeDataItem.Data
                $Headers=$PipeDataItem.Headers
                if ($Title -eq '') {$Title = $PipeDataItem.TypeString}
                if ($Caption -eq '') {$Caption = $Title}
                table -Data $Data -Headers $Headers -Title $Title -Caption $Caption
            }
        }
        else {
            [array]$Data = $PipeData
            #Create a single master list of headers in the order in which they are seen.
            if ($Headers.Count -eq 0) {
                $HeaderHT=@{}
                foreach ($DataItem in $PipeData) {
                    try {[array]$HeadersGroup= $DataItem.Keys |Where-Object{$_}| Where-Object{$_.gettype().name -match 'Collection'}}
                    catch {
                        [array]$HeadersGroup=@()
                    }
                    if ($HeadersGroup.count -eq 0) {
                        $HeadersGroup = $DataItem.psobject.Properties.name
                    }
                    $Headers += $HeadersGroup | Where-object{$null -eq $HeaderHT[$_]} | Foreach-object{$_;$HeaderHT.add($_,$True)}
                }
            }
            if ($Title -eq '')   {$Title = ($Data|Where-Object{$_}|Select-Object -First 1).gettype().Name}
            if ($Caption -eq '') {$Caption = $Title}
            table -Data $Data -Headers $Headers -Title $Title -Caption $Caption
        }
    }
}

Function Convertto-DOMHTable {
    param (
        [array]$InputObject,
        [switch]$Horizontal,
        [switch]$Title,
        [switch]$Caption,
        [string[]]$Headers,
        [switch]$isHashtbable,
        [int]$MaxDepth=2,
        [int]$Depth=1,
        [switch]$NestTables
    )
    begin {
        Function HTable {
            param (
                $Data,$Headers,
                $Title,$Caption,
                [switch]$isHashtbable=$isHashtbable,
                [int]$MaxDepth=$MaxDepth,
                [int]$Depth=$Depth,
                [switch]$NestTables=$NestTables
            )
            (.{'<table title="'+([System.Web.HttpUtility]::HtmlEncode($Title))+'">'
            '<caption>'+([System.Web.HttpUtility]::HtmlEncode($Caption))+'</caption>'
            '<tr>'+(
                (1..($Data.count))|ForEach-Object{
                    '<th>'+"Item $_"+'</th>'
                }
            )+'</tr>'
            foreach ($HeaderItem in $Headers) {
                '<tr>'
                foreach ($DataItem in $Data) {
                        '<td>'
                        if ($isHashtbable) {
                            $V = $DataItem[$HeadrerItem]
                        } ELSE {
                            $V = $DataItem.($HeadrerItem)
                        }
                        if ($null -eq $V) {'<td></td>'}
                        else {
                            '<td>'+$V+'</td>'
                        }
                        else {
                            if ($NestTables) {
                                Convertto-DOM -InputObject $V -Depth ($Depth+1) -HorizontalTables
                            }
                            else {
                                (($V | Format-List|out-string) -replace '\s*$' -split '\s*\n\s*' |Where-Object{$_}) -join '<br>'
                            }
                        }
                        '</td>'
                }
                '</tr>'
            }
            '</table>'})  -replace '\n','<br>'
        }
    } #htable
    process {
    }
    end {

    }
}

function Write_Body {
    param (
        $TagData,
        $Content,
        [int]$indent = 1
    )
    indent -Indent $Indent -Text ('<BODY '+$TagData+'>')
    Write_Tag -Tag nav -TagData "class='cssmenu'" -content (. "$Global:Project_Apps\Menu\Menu.ps1")
    Write_Tag -Tag header -TagData "class='header'" -content (&{
        $Global:Include_HTML_Header
        Write_Tag -Tag SPAN -TagData "class='Navigation'" -content $Global:Include_HTML_Navigation
    })
    Write_Tag -Tag article -TagData "class='MainBody'" -content $Content
    Write_Tag -Tag footer -TagData "class='footer'" -content $Global:Include_HTML_Footer
    indent -Indent $Indent -Text '</BODY>'
}

function Write_Script {
    param ($TagData,$Content)
    '<Script '+$TagData+'>'+"`n"
    $Content+"`n"
    '</Script>'
}

function Write_Style {
    param ($TagData,$Content)
    '<Style '+$TagData+'>'+"`n"
    indent -Indent 1 -Text $Content
    '</Style>'
}

function Write_Head {
    Write_Tag -Tag 'Head' -Content ( &{
        $Global:Include_CSS 
        $Global:Include_Java
    })
}

function Write_HTML {
    param ($TagData,$Content)
    '<HTML '+$TagData+'>'
    ''
    Write_Head
    ''
    write_body -Content $content
    ''
    '</HTML>'
}

Function Write_Img_Base64Encoded {
    param (
        $Tag = "IMG",
        $TagData,
        $ImageFormat = "bmp",
        $File,
        $Bytes
    )
    if ($File)
    {
        $BitmapBase64 = [convert]::ToBase64String((get-content -Path $File -Encoding byte))
    }
    ELSE
    {
        $BitmapBase64 = [convert]::ToBase64String($Bytes)
    }
    return ("<$Tag $TagData src='data:image/$ImageFormat;base64,"+$BitmapBase64+"' alt='Embeded Image'/>")
}

function Indent {
    param (
        [int]$Indent,
        [string[]]$Text
    )
    begin {
        if ($Text)
        {
            $Text -split "`n" | Foreach-Object {"`n" + ((0..($Indent))|Foreach-Object {"`t"})+$_}
        }
    }
    process {
        $_ -split "`n" | Where-Object {$_} | Foreach-Object {"`n" + ((0..($Indent))|Foreach-Object {"`t"})+$_} 
    }
    end {}
}

function Write_Tag {
    param (
        $Tag,
        $TagData,
        $Content,
        [int]$Indent = 1
    )
    begin {
        $O = '<'+$Tag+' '+$TagData+'>' + (($content -split "`n" | Where-Object {$_}) -join "`n")
    }
    Process {
        $O = $O + (($_ -split "`n" ) -join "`n")
    }
    End {
        $O = $O + '</'+$Tag+'>'
        $O
    }
}

Function Append_Table {
    param (
        $InputObject,
        [string[]]$AppendTableBufferProps,
        [hashtable]$AppendTableBufferPropsHT,
        [switch]$Horizontal
    )
    begin {
        $InputObject | Append_Table
        Function Completeit {
            Complete_Table -AppendTableBuffer $AppendTableBuffer -AppendTableBufferProps $AppendTableBufferProps -AppendTableBufferPropsHT $AppendTableBufferPropsHT -Horizontal:$Horizontal 
        }
    }
    process {
        $InputObjectItem = $_
        if ($null -eq $InputObjectItem) {}
        else {
            $AppendTableBuffer+=$InputObjectItem
        }
    }
    end {
        . Completeit
    }
}

Function Complete_Table {
param (
        [array]$AppendTableBuffer=(New-Object system.collections.arraylist),
        [string[]]$AppendTableBufferProps,
        [hashtable]$AppendTableBufferPropsHT,
        [switch]$Horizontal
)    
if ($AppendTableBuffer.count -gt 0)
    {
        if ($Horizontal)
        {
            $AppendTableBuffer | Select-Object $AppendTableBufferProps | write_htable
        }
        ELSE
        {
            $AppendTableBuffer | Select-Object $AppendTableBufferProps | write_table
        }
        $AppendTableBuffer.Clear()
        $AppendTableBufferProps.Clear()
        $AppendTableBufferPropsHT.Clear()
    }
}

function Write_Table {
    param (
        $Inputobject,
        [string]$TagData, # = "border=1 style=""font-size:12px;background-color:white;color:black;""",
        [alias('TableInclude')][array]$Properties
    )
    begin {
        [System.Collections.ArrayList]$TableData=@()
        $Inputobject |Where-Object {$_ -ne $null}| Foreach-Object {$TableData.add($_)} > $null
    }
    process {
        if ($_ -ne $null) {$TableData.add($_) > $null}
    }
    End {
        [scriptblock]$HTMLEncodeSB = {$_ -replace '\<','&lt;' -replace '\>','&gt;' -replace '"','&quot;' -replace '''','&#39;' -replace '\s\s',' &nbsp'}
        if     ((& {try {[System.Web.HttpUtility]::HtmlEncode('<')} catch{}})) {$HTMLEncodeSB={[System.Web.HttpUtility]::HtmlEncode($_)}} #HttpUtility
        elseif ((& {try {[System.Net.WebUtility]::HtmlEncode('<')}  catch{}})) {$HTMLEncodeSB={[System.Net.WebUtility]::HtmlEncode($_) }} #WebUtility
        if (-not $Properties)
        {
            $PropertiesHT=@{}
            [string[]]$Properties = $TableData|
                Where-Object {$_}|
                Where-Object {$_.psobject}|
                Foreach-Object {$_.psobject.properties} | 
                Select-Object -ExpandProperty Name | 
                Where-Object {$null -eq $PropertiesHT[$_]} | 
                Foreach-Object {
                    $PropertiesHT.add($_,$True);
                    $_
                }
        }
        _table -TagData $TagData -innerHTML (.{
            _thead -innerHTML (
                $Properties | Foreach-Object {
                    (_th -innerHTML $_) + "`n"
               }
            )
            $TableDataObject | Where-Object {$_} | Foreach-Object {
                $O = $_; 
                _TR -innerHTML (.{
                    $Properties | Foreach-Object {
                        [string]$VL=($O.($_) -split '`n' | Where-Object {$_} | Foreach-Object $HTMLEncodeSB) -join "<BR>`n"
                        (_td -innerHTML $VL) + "`n"
                    }
                })
            }
        })
        $TableData.Clear()
    }
}
