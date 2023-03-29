Function Set-ContextResponseToFileContents {
    Param (
        $SessionObject=(Get-WebhostSessionObject),
        [string[]]$Path,
        [string]$Encoding='Byte',
        [ValidateSet('public','private','no-cache','no-store')]
        $CachePolicy='no-cache',
        [int]$CacheMaxage=300
    )
    return (Write-Warning -Message "Set-ContextResponseToFileContents is incomplete.")
    Set_CacheControl -SessionObject $SessionObject -Policy  -MaxAge $CacheMaxage
    if (Test-Path $Path) {
        [byte[]]$Data = get-content -encoding $Encoding -Path $Path
        
        try {
        #$SessionObject.context.response.

        }
        catch {
            $SessionObject.context.response.close()
            $SessionObject.context.response.dispose()
        }
    }
    Write_log -SessionObject $SessionObject -Message 'File not found: $Path'
}
