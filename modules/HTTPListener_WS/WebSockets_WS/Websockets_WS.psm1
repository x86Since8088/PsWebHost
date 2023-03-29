# Define the function to handle WebSocket connections
function HandleWebSocketConnection($context) {
    Import-Module "$global:Project_Modules\PSGalery\JWT"
    # Authenticate the WebSocket connection with JWT
    $headers = $context.WebSocket.GetMessageHeaders()
    $authHeader = $headers['Authorization']
    $jwtToken = $authHeader.Split(' ')[1]
    $jwtPayload = Get-JwtPayload -Token $jwtToken -Secret $jwtSecretKey
    if ($null -eq $jwtPayload) {
        $context.WebSocket.Close(4001, "Unauthorized")
        return
    }
    $userId = $jwtPayload["sub"]
    Write-Host "WebSocket connection authenticated for user $userId"
    
    # Handle the WebSocket messages
    $buffer = New-Object Byte[] 4096
    while ($true) {
        $result = $context.WebSocket.Receive($buffer)
        if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            Write-Host "WebSocket connection closed for user $userId"
            break
        }
        $message = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
        Write-Host "WebSocket message received from user $userId`: $message"
        # Handle the WebSocket message here
    }
}