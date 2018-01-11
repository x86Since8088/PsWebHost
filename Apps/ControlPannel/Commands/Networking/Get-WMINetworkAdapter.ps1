param (
	$ComputerName = $env:computername, 
	$debug = 1
)
$jobs_server_NetworkAdapters = New-Object System.Collections.ArrayList
$WMIServerNetworkAdapters = @()
$ComputerName -split ",|;|`n|\s" | ?{$_} |% {
    $cp = $_ 
    if ($debug -gt 0) {write-host "Setting up job : Get-WMIobject on " $cp}
    $newjob = Get-WmiObject win32_NetworkAdapter -ComputerName $cp -asjob
    $jobs_server_NetworkAdapters.add($newjob)
}

$jobs_server_NetworkAdapters |get-job | wait-job
& {
    foreach ($job in ( $jobs_server_NetworkAdapters | ?{$_.state -eq "completed"})) {
      if ($job -ne $null) {
        $job | get-job -ErrorAction "silentlycontinue" | Receive-Job -ErrorAction "silentlycontinue" | %{
          $WMIServerNetworkAdapter = $_
          $WMIServerNetworkAdapter
          $WMIServerNetworkAdapters += $WMIServerNetworkAdapter
        }
        $job | stop-job | out-null
        $job | remove-job | out-null
        $jobs_test_connection | ?{$_ -eq $job} 
        $jobs_test_connection = ($jobs_test_connection | ?{$_ -ne $job} )
        $jobs_server_NetworkAdapters
      }
    }
} | write_table

