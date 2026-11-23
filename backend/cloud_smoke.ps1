param(
    [string]$Api = 'https://api.smilequest.ru',
    [string]$ExerciseWs = 'wss://exercise.smilequest.ru/ws'
)

$ErrorActionPreference = 'Stop'
$health = Invoke-RestMethod -Uri "$Api/health"
if ($health.status -ne 'ok') { throw 'Data API health failed' }
$exerciseHealthUri = [System.UriBuilder]::new($ExerciseWs)
$exerciseHealthUri.Scheme = if ($exerciseHealthUri.Scheme -eq 'wss') { 'https' } else { 'http' }
$exerciseHealthUri.Path = '/health'
$exerciseHealthUri.Query = ''
$exerciseHealthUri.Fragment = ''
$exerciseHealth = Invoke-RestMethod -Uri $exerciseHealthUri.Uri
if ($exerciseHealth.status -ne 'ok') { throw 'Exercise API health failed' }

$email = "cloud-smoke-$([guid]::NewGuid().ToString('N').Substring(0, 12))@example.com"
$signup = Invoke-RestMethod -Method Post -Uri "$Api/auth/signup" -ContentType 'application/json' -Body (@{
    email = $email
    password = [guid]::NewGuid().ToString('N')
    full_name = 'Test Patient'
} | ConvertTo-Json -Compress)
if (-not $signup.token) { throw 'Signup did not return a token' }
$headers = @{ Authorization = "Bearer $($signup.token)" }
$me = Invoke-RestMethod -Uri "$Api/auth/me" -Headers $headers
if ($me.email -ne $email) { throw 'Authenticated user does not match' }

$profile = Invoke-RestMethod -Method Patch -Uri "$Api/profile" -Headers $headers -ContentType 'application/json' -Body (@{
    pet_name = 'Frog'
} | ConvertTo-Json -Compress)
if ($profile.pet_name -ne 'Frog') { throw 'Profile update failed' }

$socket = [System.Net.WebSockets.ClientWebSocket]::new()
try {
    [void]$socket.ConnectAsync([uri]$ExerciseWs, [threading.cancellationtoken]::None).GetAwaiter().GetResult()
    $payload = [text.encoding]::UTF8.GetBytes((@{ mode = 'auth'; token = $signup.token } | ConvertTo-Json -Compress))
    [void]$socket.SendAsync([arraysegment[byte]]::new($payload), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [threading.cancellationtoken]::None).GetAwaiter().GetResult()
    $buffer = New-Object byte[] 8192
    $result = $socket.ReceiveAsync([arraysegment[byte]]::new($buffer), [threading.cancellationtoken]::None).GetAwaiter().GetResult()
    $message = [text.encoding]::UTF8.GetString($buffer, 0, $result.Count) | ConvertFrom-Json
    if ($message.status -ne 'authenticated') { throw "Exercise WSS authentication failed: $($message.error)" }
} finally {
    $socket.Dispose()
}

Write-Output 'OK: HTTPS health, signup, profile and authenticated exercise WSS'
