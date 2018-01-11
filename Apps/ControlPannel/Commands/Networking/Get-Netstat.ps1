$Connections = @()  
    & {
      [net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpConnections() | %{
        $connection = $_
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "protocol"      -value "tcp"
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalAddress"  -value ($connection.LocalEndPoint.tostring()).split(":")[0]
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalPort"     -value ($connection.LocalEndPoint.tostring()).split(":")[1]
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "RemoteAddress" -value ($connection.RemoteEndPoint.tostring()).split(":")[0]
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "RemotePort"    -value ($connection.RemoteEndPoint.tostring()).split(":")[1]
        $connection
      }
      [net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | %{
        $connection = $_
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "protocol"     -value "tcp"
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "State"        -value "Listening"
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalAddress" -value $connection.address
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalPort"    -value $connection.port
        $connection
      }
      [net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners() | %{
        $connection = $_
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "protocol"     -value "udp"
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "State"        -value "Listening"
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalAddress" -value $connection.address
        Add-Member -MemberType NoteProperty -InputObject $connection -Name "LocalPort"    -value $connection.port
        $connection
      }
  } | Write_Table -TableInclude protocol,State,LocalAddress,LocalPort,RemoteAddress,RemoteAddress,RemotePort
