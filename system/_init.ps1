###################################
# Variable initialization
###################################
#  Load variables before starting job so they can also be used for debugging.
#  . .\SimpleWebHost.ps1 -LoadVariables - will load and variables and exit with a friendly message.

Write-Verbose -Message 'Resetting Global:PSWebServer.' -Verbose
$Global:PSWebServer           = [hashtable]::Synchronized(@{})

Write-Verbose -Message 'Initializing variables.' -Verbose
$Global:PSWebServer.InitializingScript =
                                    $MyInvocation.MyCommand.Name
[string]$ScriptPath               = $MyInvocation.MyCommand.Definition | Where-Object { Test-Path $_ }
                                    if ($ScriptPath -eq '') { return 'scriptpath not resolved' }
[string]$ScriptName               = Split-Path -Leaf $ScriptPath
[string]$Project_Root             = split-path (split-path $ScriptPath)
[string]$Project_RootName         = split-path -Leaf $Project_Root
[string]$Project_Data             = "$Project_Root\$($Project_RootName)_DataStore"
$Global:PSWebServer.Project_Root  = [hashtable]::Synchronized(@{Path=$Project_Root})
$Global:PSWebServer.system        = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Root.Path + '\system'})
$Global:PSWebServer.routes        = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Root.Path + '\routes'})
$Global:PSWebServer.modules       = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Root.Path + '\modules'})
$Global:PSWebServer.Project_Data  = [hashtable]::Synchronized(@{Path=$Project_Data})
$Global:PSWebServer.logs          = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Data.Path + '\logs'})
$Global:PSWebServer.events        = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Data.Path + '\events'})
$Global:PSWebServer.error         = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Data.Path  + '\error'})
$Global:PSWebServer.kv            = [hashtable]::Synchronized(@{Path=$Global:PSWebServer.Project_Data.Path + '\kv'})
                                    $Global:PSWebServer.Values.Path | #Catches all the *.paths that need to be created.
                                        Where-Object{! (test-path $_)}|
                                        Foreach-Object{ mkdir $_ }
                                    Set-Location $Global:PSWebServer.Project_Root.Path
[datetime]$Start                  = Get-Date
$Global:PSWebServer.Started       = $Start
$Global:PSWebServer.logs.default  = "$Project_Root\logs\$ScriptName`_$($Start.ToString('yyyMMdd')).log"

function Get-PSWebKVData {
    param (
        [string]$Key
    )
    if (!(Test-Path $Global:PSWebServer.kv.Path\$Key.json)) {
        return @{
            key = $Key
            status = 'file missing'
        }
    }
    $KVData = Get-Content -Path $Global:PSWebServer.kv.Path\$Key.json -Raw -ErrorAction SilentlyContinue | 
        ConvertFrom-Json
    return @{
        status = 'success'
        data = $KVData
    }
}

function Set-PSWebKVData {
    param (
        [string]$Key,
        [hashtable]$Data,
        [int]$Depth = 10,
        [byte[]]$EncryptionKey = $Global:PSWebServer.DefaultEncryptionKey
    )
    if ($Data -eq $null) {
        return @{
            status = 'data is null'
        }
    }
    if ($EncryptionKey.Length -ne 0) {
        Write-Verbose -Message "Using EncryptionKey provided KV data. for $Key." -Verbose
        $Encryption
    }
    else {
        [array]$ErrorData = .{$Data | ConvertTo-Json -Depth 10 | Set-Content -Path $Global:PSWebServer.kv.Path\$Key.json -Force}2>&1
        return @{
            status = if ($ErrorData.count) {'error'} else {'success'}
            data = $Data
            error = $ErrorData
        }
    }
}

function Protect-PSWebData {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [byte[]]$Data,

        [Parameter(Mandatory=$true)]
        [byte[]]$Key,

        [Parameter(Mandatory=$true)]
        [byte[]]$IV
    )

    Process {
        $aes = New-Object System.Security.Cryptography.AesManaged
        $aes.Key = $Key
        $aes.IV = $IV

        $encryptor = $aes.CreateEncryptor($aes.Key, $aes.IV)
        $memoryStream = New-Object System.IO.MemoryStream
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)

        $cryptoStream.Write($Data, 0, $Data.Length)
        $cryptoStream.FlushFinalBlock()

        $encrypted = $memoryStream.ToArray()

        $memoryStream.Close()
        $cryptoStream.Close()

        return $encrypted
    }
}
function Get-PSWebSHAHash {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$InputString,

        [Parameter(Mandatory=$true)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # List of available hash algorithms
            # Use reflection to get static properties of HashAlgorithmName
            $hashAlgorithmNameType = [System.Security.Cryptography.HashAlgorithmName]
            $staticProperties = $hashAlgorithmNameType.GetProperties([System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public)
            $hashAlgorithms = foreach ($prop in $staticProperties) {
                $prop.GetValue($null).Name
            }
            # Filter the list based on the current user input
            $hashAlgorithms | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
        })]
        [System.Security.Cryptography.HashAlgorithmName]$Algorithm
    )
    begin {
        $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::create($Algorithm)

    }
    Process {

        try {
            $byteArray = [System.Text.Encoding]::UTF8.GetBytes($InputString)
            $hashArray = $hashAlgorithm.ComputeHash($byteArray)
            return [BitConverter]::ToString($hashArray).Replace("-", "")
        }
        finally {
            if ($hashAlgorithm) {
                $hashAlgorithm.Dispose()
            }
        }
    }
}

function Get-PSWebSHAHashStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$InputString,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [System.IO.Stream]$InputStream,
        [Parameter(Mandatory=$true)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # List of available hash algorithms
            # Use reflection to get static properties of HashAlgorithmName
            $hashAlgorithmNameType = [System.Security.Cryptography.HashAlgorithmName]
            $staticProperties = $hashAlgorithmNameType.GetProperties([System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public)
            $hashAlgorithms = foreach ($prop in $staticProperties) {
                $prop.GetValue($null).Name
            }
            # Filter the list based on the current user input
            $hashAlgorithms | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
        })]
        [System.Security.Cryptography.HashAlgorithmName]$hashAlgorithmName
    )
    begin {
        $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::create($hashAlgorithmName)
        # Define the size of the buffer.
        $bufferSize = 1MB
        $buffer = New-Object byte[] $bufferSize
    }
    Process {
        try {
            # Check if input is a string and convert it to a stream if necessary
            if ('' -ne $InputString) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
                $InputStream = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
            }

            # Read chunks of the stream and update the hash algorithm
            do {
                $count = $InputStream.Read($buffer, 0, $bufferSize)
                if ($count -gt 0) {
                    $HashAlgorithm.TransformBlock($buffer, 0, $count, $null, 0) > $null
                }
            }
            while ($count -gt 0)
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
    End {
        # Finalize the hash computation
        $HashAlgorithm.TransformFinalBlock($buffer, 0, 0)
        $hashBytes = $HashAlgorithm.Hash

        # Convert hash bytes to a hex string
        return [BitConverter]::ToString($hashBytes).Replace("-", "")

        # Dispose of the stream if it was created from a string
        if ($InputString -ne $null) {
            $InputStream.Dispose()
        }
    }  
}


###################################
# Load PS modules for project
###################################
$Global:PSWebServer.modules.Updated   = Get-Date
$Global:PSWebServer.modules.psm1      = Get-ChildItem -Path $Global:PSWebServer.modules.Path -Filter *.psm1 -recurse|
                                            Where-Object { $_.fullname -notmatch 'private' }
                                        $Global:PSWebServer.modules.psm1|
                                            Sort-Object -Property fullname|
                                            Sort-Object -Property basename -Unique|
                                            Where-Object{
                                                #($_.Directory.name -eq $_.baseName) -or
                                                ($_.fullname -match "(\\|/)$([regex]::Escape($_.BaseName))(\\|/)")
                                            }|
                                            ForEach-Object {
                                                try { remove-module -ErrorAction SilentlyContinue -Name $_.basename -Verbose } catch {}
                                                import-module $_.Fullname -DisableNameChecking -Force -Verbose
                                            }

###################################
# Declare URLs that will be used.
###################################
. "$($Global:PSWebServer.system.Path)\Bindings.ps1"
