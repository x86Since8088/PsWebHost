class Base {
    [string]$hostname
    [int]$port
    [string]$pass
    [int]$subs
    [object]$ws
    [object]$cts
    [object]$ct
    [object]$recv_queue
    [object]$send_queue
    [object]$recv_job
    [object]$send_job
    [object]$recv_runspace
    [object]$send_runspace
    [object]$data

    Base ([string]$hostname, [int]$port, [string]$pass, [int]$subs) {
        $this.hostname = $hostname
        $this.port = $port
        $this.pass = $pass
        $this.subs = $subs

        $this.ws = New-Object Net.WebSockets.ClientWebSocket
        $this.cts = New-Object Threading.CancellationTokenSource
        $this.ct = New-Object Threading.CancellationToken($false)

        $connectTask = $this.ws.ConnectAsync("ws://$($this.hostname):$($this.port)", $this.cts.Token)
        do { Start-Sleep(1) }
        until ($connectTask.IsCompleted)

        $this.recv_queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[String]'
        $this.send_queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[String]' 

        $this.recv_job = {
            param($ws, $recv_queue)
        
            $buffer = [Net.WebSockets.WebSocket]::CreateClientBuffer(1024, 1024)
            $ct = [Threading.CancellationToken]::new($false)
            $taskResult = $null
        
            while ($ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
                $jsonResult = ""
                do {
                    $taskResult = $ws.ReceiveAsync($buffer, $ct)
                    while (-not $taskResult.IsCompleted -and $ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
                        [Threading.Thread]::Sleep(10)
                    }
        
                    $jsonResult += [Text.Encoding]::UTF8.GetString($buffer, 0, $taskResult.Result.Count)
                } until (
                    $ws.State -ne [Net.WebSockets.WebSocketState]::Open -or $taskResult.Result.EndOfMessage
                )
        
                if (-not [string]::IsNullOrEmpty($jsonResult)) {
                    #"Received message(s): $jsonResult" | Out-File -FilePath "logs.txt" -Append
                    $recv_queue.Enqueue($jsonResult)
                }
            }
        }
        $this.send_job = {
            param($ws, $send_queue)
        
            $ct = New-Object Threading.CancellationToken($false)
            $workitem = $null
            while ($ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
                if ($send_queue.TryDequeue([ref] $workitem)) {
                    #"Sending message: $workitem" | Out-File -FilePath "logs.txt" -Append
        
                    [ArraySegment[byte]]$msg = [Text.Encoding]::UTF8.GetBytes($workitem)
                    $ws.SendAsync(
                        $msg,
                        [System.Net.WebSockets.WebSocketMessageType]::Text,
                        $true,
                        $ct
                    ).GetAwaiter().GetResult() | Out-Null
                }
            }
        }

        $this.InitRunspaces()
        $this.RunHandler()
    }

    [void] InitRunspaces() {
        "Starting recv runspace" | Write-Debug
        $this.recv_runspace = [PowerShell]::Create()
        $this.recv_runspace.AddScript($this.recv_job).
        AddParameter("ws", $this.ws).
        AddParameter("recv_queue", $this.recv_queue).BeginInvoke() | Out-Null
        
        "Starting send runspace" | Write-Debug
        $this.send_runspace = [PowerShell]::Create()
        $this.send_runspace.AddScript($this.send_job).
        AddParameter("ws", $this.ws).
        AddParameter("send_queue", $this.send_queue).BeginInvoke() | Out-Null
    }

    [object] RunHandler() {
        $msg = $null
        $timeout = New-TimeSpan -Seconds 5
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            while ($this.recv_queue.TryDequeue([ref] $msg)) {
                Write-Debug "Processed message: $msg"
                $this.data = $msg | ConvertFrom-Json
                switch ($this.data.op) {
                    0 { $this.Identify(); return $null }
                    2 { return $this.data.op }
                    5 { return @($this.data.d.EventType, $this.data.d.EventData) }
                    7 { return $this.data.d.responseData }
                }
            }
        } until ($stopwatch.elapsed -gt $timeout)
        return $null
    }

    [void] TearDown() {
        "Closing WS connection" | Write-Debug
        $closetask = $this.ws.CloseAsync(
            [System.Net.WebSockets.WebSocketCloseStatus]::Empty,
            "",
            $this.ct
        )
    
        do { Start-Sleep(1) }
        until ($closetask.IsCompleted)
        $this.ws.Dispose()
    
        "Stopping runspaces" | Write-Debug
        $this.recv_runspace.Stop()
        $this.recv_runspace.Dispose()
    
        $this.send_runspace.Stop()
        $this.send_runspace.Dispose()
    }

    [void] Identify() {
        $Payload = @{
            op = 1
            d  = @{
                rpcVersion         = 1
                eventSubscriptions = $this.subs
            }
        }
        if ( $null -ne $this.data.d.authentication ) {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($this.pass + $this.data.d.authentication.salt)
            $Secret = [Convert]::ToBase64String($hasher.ComputeHash($secretBytes))
            $authBytes = [System.Text.Encoding]::UTF8.GetBytes(
                $Secret + $this.data.d.authentication.challenge
            )
            $auth = [Convert]::ToBase64String($hasher.ComputeHash($authBytes))
            $Payload["d"]["authentication"] = $auth
        }
    
        $json = $Payload | ConvertTo-Json
        $this.send_queue.Enqueue($json)
    }
}

Function Get-Base {
    param($hostname, $port, $pass, $subs = 0)
    return [Base]::new($hostname, $port, $pass, $subs)
}
