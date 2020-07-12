#https://stackoverflow.com/questions/54943838/how-to-find-url-registrations-not-reservations
function Parse-HttpSysReqQueue() {
    [string[]]$rawHttpSysQueue = netsh http show servicestate view=requestq verbose=no

    $urls = @()
    $output = @()
    $recordIsOpen = $false
    $index = 0
    $rawHttpSysQueue | ForEach-Object {
        $line = $_

        # Whether is the begining of a new request queue record.
        $newRecordToken = "Request queue name"
        if ($line.StartsWith($newRecordToken)) {
            $recordIsOpen  = $true
            $index++; return
        }

        # We are iterating through a request-queue record.
        if ($recordIsOpen) {

            # Obtain Process ID
            if ($line.Contains("Process IDs:")) {
                $rawPid = $rawHttpSysQueue[$index+1]
                if($rawPid.Trim() -match '^\d+$'){
                    $processId = $rawPid.Trim()
                } else {
                    $processId = $null
                }
                $index++; return
            }

            # Obtain Controller Process ID (generally IIS)
            if ($line.Contains("Controller process ID:")) {
                $controllerProcessId = $line.Split(":")[1].Trim()
                $index++; return
            }

            # Read all registered urls from current record.
            if ($line.Contains("Registered URLs:")) {
                $urlLineIndex = $index+1
                while ($rawHttpSysQueue[$urlLineIndex].Trim().StartsWith("HTTP://") -or $rawHttpSysQueue[$urlLineIndex].Trim().StartsWith("HTTPS://")) {
                    $urls += $rawHttpSysQueue[$urlLineIndex].Trim()
                    $urlLineIndex++
                }

                # Add record to output list.
                $urls | ForEach-Object {
                    $output += New-Object PSObject -Property @{
                        ProcessId = $processId
                        RegisteredUrl = $_
                        ControllerProcessId = $controllerProcessId
                    }
                }

                # Already read all the urls from this request-queue, consider the record closed.
                $processId = $null
                $controllerProcessId = $null
                $urls = @()
                $recordIsOpen = $false
            }
        }
        $index++
    }

    return $output
}