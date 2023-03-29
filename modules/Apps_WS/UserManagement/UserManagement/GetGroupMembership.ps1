Function GetGroupMembership {
    Param (
        [string]$Name,
        [System.Collections.ArrayList]$GroupMembership = (New-Object System.Collections.ArrayList),
        $Searchon = 'samaccountname'
    )
        
    GetADGroupMembership -Name $Name -GroupMembership $GroupMembership 
} 
