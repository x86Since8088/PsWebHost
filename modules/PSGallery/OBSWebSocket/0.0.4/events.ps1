. $PSScriptRoot\base.ps1
. $PSScriptRoot\subs.ps1


class OBSWebSocketError : Exception {
    [string]$msg

    OBSWebSocketError ([string]$msg) {
        $this.msg = $msg
    }

    [string] ErrorMessage () {
        return $this.msg
    }
}


class Event {
    [object]$base
    [hashtable]$callbacks
    [bool]$close

    Event ([string]$hostname, [int]$port, [string]$pass, [int]$subs) {
        $this.base = Get-Base -hostname $hostname -port $port -pass $pass -subs $subs
        if (!($this.base.RunHandler() -eq 2)) { 
            $this.Teardown()
            throw [OBSWebSocketError]::new("Failed to identify $this client with server")
            exit
        }
        "Successfully identified $this client with server" | Write-Debug 
        $this.callbacks = @{}
    }

    [void] Register($callbacks) {
        if ($callbacks[0] -is [array]) { 
            $callbacks | ForEach-Object {
                $name, $fn = $_
                $name + " registered to callbacks" | Write-Debug
                $this.callbacks[$name] = $fn        
            }
        }
        else { 
            $name, $fn = $callbacks
            $name + " registered to callbacks" | Write-Debug
            $this.callbacks[$name] = $fn 
        }
        $this.Listen()   
    }

    [void] Trigger($eventType, $eventData) {
        if ($this.callbacks.ContainsKey($eventType)) {
            & $this.callbacks[$eventType]($eventData)
        }
    }

    [void] Listen() {
        do {
            do {
                $type, $data = $this.base.RunHandler()
            } until ($this.base.data.op -eq 5)
            if ($type) { $this.Trigger($type, $data) }
        } until ( $this.base.data.d.EventType -eq "ExitStarted" )
    }

    [void] TearDown() {
        $this.base.Teardown()
    }
}
