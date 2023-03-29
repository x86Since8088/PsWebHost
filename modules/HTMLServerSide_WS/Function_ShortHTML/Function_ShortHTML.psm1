#Make Quick HTMLTag shortcuts
$Invocation=$MyInvocation
$tempscriptname = ($MyInvocation.MyCommand.Definition,$MyInvocation.MyCommand.Module.Path|?{$_ -match '^(\\\\|\w:)'}|?{try{test-path $_}catch{}})
$TagsFile = $tempscriptname -replace '\.psm{0,1}1','_Tags.txt'
$TagsFileObj = Get-Item $TagsFile
#Update tags file
<#
if ($TagsFileObj.LastWriteTime.adddays(30) -lt (get-date))
{
    $Taglist = New-Object System.Collections.ArrayList
    
    (curl -UseBasicParsing https://www.w3schools.com/TAGs/ref_byfunc.asp).Content -split '\<|\>' -match '\&lt;' | %{
        $_ -split '\&lt;' | select -last 1| %{
            $_ -split '\&gt;' | select -First 1
        } 
    }|?{$_} | %{$Taglist.add($_)} > $null

    ((1..6)|%{"H$_"}) | %{$Taglist.add($_)} > $null
    if ($Taglist.count -gt 30)
    {
        $TagList | sort -Unique | Out-File -Encoding utf8 -FilePath $TagsFile -Force
    }
}
#>





(Get-Content $TagsFile) -split '\s|\n' | Where-Object{$_} | ForEach-Object{
    $TagName=$_
    $T=@"
function _$TagName (`$TagData,`$innerHTML,[switch]`$NoTerminatingTag) {
    '<$TagName ' + (.{
    if (`$TagData) {if (`$TagData.GetType().Name -eq 'ScriptBlock') {`$TagData=. `$TagData}}
    if (`$innerHTML) {if (`$innerHTML.GetType().Name -eq 'ScriptBlock') {`$innerHTML=. `$innerHTML}}
    
    if ( `$null -ne `$TagData  )
    {
        . {
            if ( `$TagData.gettype().name -eq 'scriptblock' ) 
            {
                . `$TagData
            } 
            ELSE 
            {
                `$TagData
            }
        }
    }
    })+'>'+(.{
    if ( `$null -ne `$InnerHTML )
    {
        . {
            `$InnerHTML
        }
    }
    })+(.{if (-not `$NoTerminatingTag){'</$TagName>'}})
}
"@

    $SB=[scriptblock]::Create($T)
    . $SB
}

