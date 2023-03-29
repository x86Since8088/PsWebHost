Function Get-Storage_WS {
    param (
        $CallingScript = (Get-PSCallStack | select -skip 1 -First 1) 
    )
    Write-Warning 'Get-Storage_WS is still under development.'
    $CallingScript
    
}