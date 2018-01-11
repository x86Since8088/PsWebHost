param (
    [scriptblock]$Filter = {-not ($_.name -match 'gzip')}
)
"Filter: " + [string]$Filter
Get-Variable | ? $Filter | select Name,Value,Options,visibility,* -erroraction silentlycontinue| write_table