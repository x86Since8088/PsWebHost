function Get_IndexAccountNumber {
    param ([string]$Email)
    $script:AccLookup_Email | ?{$_.email -eq $email} | %{$_.'Account Number'}
}
