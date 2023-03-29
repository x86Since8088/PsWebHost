# get post data from the input stream.
function ExtractPostDatafromrequest_WS ($request = $Global:Request) {
  $length = $request.contentlength64
  $buffer = new-object "byte[]" $length

  [void]$request.inputstream.read($buffer, 0, $length)
  $body = [system.text.encoding]::UTF8.getstring($buffer)

  $data = @{}
  $body.split('&') | %{
    $part = $_.split('=')
    $data.add($part[0], $part[1])
  }

  return $data
}
new-alias -Force extract -Value ExtractPostDatafromrequest_WS