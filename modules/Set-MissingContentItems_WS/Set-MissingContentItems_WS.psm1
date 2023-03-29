Function Set-MissingContentItems_WS {
    param (
        [string]$Path,
        [string]$GlobalVariableName,
        [scriptblock]$ScriptBlock = {},
        [string]$Text,
        [string]$Encoding = 'UTF8'
    )
    $SBText=$ScriptBlock.ToString()
    if ($SBText -ne '') {$Text = $SBText}
    split-path $Path | 
        Where-Object{-not (test-path $_)} |
        ForEach-Object{mkdir $_}
    if (-not (test-path $Path)) {
        $Text | Out-File -Encoding $Encoding -FilePath $Path 
    }
    if ($GlobalVariableName -ne '') {
        New-Variable -Force -Scope global -Name $GlobalVariableName -Value ((Get-Content $Path) -join "`n")
    }
}