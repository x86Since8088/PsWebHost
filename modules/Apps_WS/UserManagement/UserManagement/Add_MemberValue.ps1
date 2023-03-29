Function Add_MemberValue ($InputObject,$Name,$Value) {
        if ($InputObject.($Name) -eq $null) 
        {Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value}
        ELSE {$InputObject.($Name) = $Value}
}