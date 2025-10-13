param(
  [string]$ApiBaseUrl = "http://localhost:3003/api",
  [string]$AdminToken = "",
  [string]$FcmBaseUrl = "http://localhost:3000",
  [string]$NgrokApiUrl = "http://localhost:4040/api/tunnels",
  [string]$PublicNgrokUrl = "https://soc-chat-app.ngrok-free.app"
)

function Write-Section($title) {
  Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

function Invoke-ApiJson {
  param(
    [string]$Method,
    [string]$Url,
    [object]$Body = $null,
    [string]$Token = ""
  )
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($Token) { $headers['Authorization'] = "Bearer $Token" }
  $headers['ngrok-skip-browser-warning'] = 'true'
  try {
    if ($Body) {
      $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 6 }
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -Body $json
    } else {
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }
  } catch {
    Write-Warning "API call failed: $Method $Url"
    if ($_.Exception.Response) {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $resp = $reader.ReadToEnd()
      Write-Host $resp -ForegroundColor Yellow
    } else {
      Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
    throw
  }
}

function Upload-Media {
  param(
    [string]$UploadUrl,
    [string]$Token,
    [string]$ChatId,
    [string]$Type = 'image',
    [string]$Caption = 'E2E upload',
    [string]$FilePath
  )
  try { Add-Type -AssemblyName System.Net.Http } catch { Write-Warning "System.Net.Http not available: $($_.Exception.Message)" }
  $handler = $null
  $client = $null
  $fs = $null
  try {
    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)
    if ($Token) {
      $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Token)
    }
    $client.DefaultRequestHeaders.Add('ngrok-skip-browser-warning', 'true')
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add((New-Object System.Net.Http.StringContent($ChatId)), 'chatId')
    $content.Add((New-Object System.Net.Http.StringContent($Type)), 'type')
    if ($Caption) { $content.Add((New-Object System.Net.Http.StringContent($Caption)), 'caption') }
    $fs = [System.IO.File]::OpenRead($FilePath)
    $sc = New-Object System.Net.Http.StreamContent($fs)
    $sc.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('application/octet-stream')
    $content.Add($sc, 'file', [System.IO.Path]::GetFileName($FilePath))
    $response = $client.PostAsync($UploadUrl, $content).Result
    $respContent = $response.Content.ReadAsStringAsync().Result
    if (-not $response.IsSuccessStatusCode) {
      Write-Warning "Upload failed: $($response.StatusCode)"
      if ($respContent) { Write-Host $respContent -ForegroundColor Yellow }
      throw "Upload failed"
    }
    return $respContent | ConvertFrom-Json
  } catch {
    Write-Warning "HttpClient upload failed: $($_.Exception.Message)"
    throw
  } finally {
    if ($fs) { $fs.Dispose() }
    if ($client) { $client.Dispose() }
    if ($handler) { $handler.Dispose() }
  }
}

# Health Checks
Write-Section "API Health"
$apiHealth = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/health"
Write-Host "API status: $($apiHealth.status)" -ForegroundColor Green

Write-Section "MongoDB Connectivity"
Write-Host "DB status: $($apiHealth.database.status) | Success rate: $($apiHealth.database.successRate)" -ForegroundColor Green

Write-Section "FCM Health"
try { $fcmHealth = Invoke-ApiJson -Method GET -Url "$FcmBaseUrl/health"; Write-Host "FCM: $($fcmHealth.status)" -ForegroundColor Green } catch { Write-Warning "FCM health check failed" }

Write-Section "ngrok Status"
try {
  $tunnels = Invoke-ApiJson -Method GET -Url $NgrokApiUrl
  $active = $tunnels.tunnels | Where-Object { $_.public_url -match 'https://' }
  Write-Host "Active tunnels: $($active.Count)" -ForegroundColor Green
  $active | ForEach-Object { Write-Host "- $_.public_url -> $_.config.addr" -ForegroundColor Green }
} catch { Write-Warning "ngrok API not reachable." }

# Register/Login two users
Write-Section "Register & Login Users"
$suffix = (Get-Date).ToString('yyyyMMddHHmmss')
$user1Email = "e2e1+$suffix@example.com"
$user2Email = "e2e2+$suffix@example.com"

$reg1 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/register" -Body @{ email = $user1Email; password = "Password123!"; name = "E2E User 1" }
$reg2 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/register" -Body @{ email = $user2Email; password = "Password123!"; name = "E2E User 2" }
Write-Host "Registered: $($reg1.user.id) and $($reg2.user.id)" -ForegroundColor Green

$login1 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/login" -Body @{ email = $user1Email; password = "Password123!" }
$login2 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/login" -Body @{ email = $user2Email; password = "Password123!" }
$token1 = $login1.token
$token2 = $login2.token
$user1Id = $login1.user.id
$user2Id = $login2.user.id
Write-Host "Logged in; tokens issued." -ForegroundColor Green

# Auth User
Write-Section "Auth User"
try { $me = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/auth/user" -Token $token1; Write-Host "Me: $($me.user.id)" -ForegroundColor Green } catch { Write-Warning "Auth user endpoint unavailable; continuing." }

# Create One-on-One Chat
Write-Section "Create 1:1 Chat"
$chatCreate = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/chats" -Body @{ name = "E2E 1:1"; members = @($user1Id, $user2Id) } -Token $token1
$chatId = if ($chatCreate.chat) { $chatCreate.chat.id } else { $chatCreate.id }
Write-Host "1:1 chat: $chatId" -ForegroundColor Green

# Create Group Chat with admin if AdminToken provided (assumes admin user id=1 or resolved via admin/users)
Write-Section "Create Group Chat"
$groupMembers = @($user1Id, $user2Id)
if ($AdminToken) {
  try {
    $adminUsers = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/users?limit=1" -Token $AdminToken
    if ($adminUsers.users.Count -gt 0) { $groupMembers += $adminUsers.users[0].id }
  } catch { Write-Warning "Admin users listing failed; creating group with test users only." }
}
$groupCreate = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/chats" -Body @{ name = "E2E Group"; members = $groupMembers } -Token $token1
$groupChatId = if ($groupCreate.chat) { $groupCreate.chat.id } else { $groupCreate.id }
Write-Host "Group chat: $groupChatId" -ForegroundColor Green

# Send Text Message to 1:1
Write-Section "Send Text Message"
$baseNoApi = $ApiBaseUrl -replace '/api$',''
try { $msg1 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/chats/$($chatId)/messages" -Body @{ content = "Hello from E2E"; messageType = "text" } -Token $token1 } catch { $msg1 = Invoke-ApiJson -Method POST -Url "$baseNoApi/chats/$($chatId)/messages" -Body @{ content = "Hello from E2E"; messageType = "text" } -Token $token1 }
$msg1Id = if ($msg1.id) { $msg1.id } elseif ($msg1.messageData) { $msg1.messageData.id } else { $msg1.id }
Write-Host "Text message sent: $msg1Id" -ForegroundColor Green

# Send Media to Group
Write-Section "Send Media Message"
$tempDir = Join-Path $env:TEMP "soc-chat-e2e"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$tempFile = Join-Path $tempDir "e2e-upload.txt"
"Hello media from E2E" | Out-File -FilePath $tempFile -Encoding UTF8
$uploadResp = Upload-Media -UploadUrl "$ApiBaseUrl/media/upload" -Token $token1 -ChatId $groupChatId -Type 'document' -Caption 'E2E' -FilePath $tempFile
Write-Host "Uploaded: $($uploadResp.fileName) -> $($uploadResp.mediaUrl)" -ForegroundColor Green

# List Messages for both chats
Write-Section "List Messages"
try { $msgs1 = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/chats/$($chatId)/messages?limit=5" -Token $token1 } catch { $msgs1 = Invoke-ApiJson -Method GET -Url "$baseNoApi/chats/$($chatId)/messages?limit=5" -Token $token1 }
try { $msgs2 = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/chats/$($groupChatId)/messages?limit=5" -Token $token1 } catch { $msgs2 = Invoke-ApiJson -Method GET -Url "$baseNoApi/chats/$($groupChatId)/messages?limit=5" -Token $token1 }
$count1 = if ($msgs1.messages) { $msgs1.messages.Count } else { $msgs1.Count }
$count2 = if ($msgs2.messages) { $msgs2.messages.Count } else { $msgs2.Count }
Write-Host "1:1 messages: $count1 | Group messages: $count2" -ForegroundColor Green

# Notifications flow
Write-Section "Notifications"
try {
  try { $notif = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/notifications" -Body @{ userId = $user1Id; type = "info"; title = "E2E"; message = "E2E notification" } -Token $token1 } catch { $notif = Invoke-ApiJson -Method POST -Url "$baseNoApi/notifications" -Body @{ userId = $user1Id; type = "info"; title = "E2E"; message = "E2E notification" } -Token $token1 }
  $notifId = if ($notif.notification) { $notif.notification.id } else { $notif.id }
  try { $notifs = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/notifications?unreadOnly=true&limit=5" -Token $token1 } catch { $notifs = Invoke-ApiJson -Method GET -Url "$baseNoApi/notifications?unreadOnly=true&limit=5" -Token $token1 }
  try { $markRead = Invoke-ApiJson -Method PUT -Url "$ApiBaseUrl/notifications/$notifId/read" -Token $token1 } catch { $markRead = Invoke-ApiJson -Method PUT -Url "$baseNoApi/notifications/$notifId/read" -Token $token1 }
  try { $markAll = Invoke-ApiJson -Method PUT -Url "$ApiBaseUrl/notifications/read-all" -Token $token1 } catch { $markAll = Invoke-ApiJson -Method PUT -Url "$baseNoApi/notifications/read-all" -Token $token1 }
  try { $notifDelete = Invoke-ApiJson -Method DELETE -Url "$ApiBaseUrl/notifications/$notifId" -Token $token1 } catch { $notifDelete = Invoke-ApiJson -Method DELETE -Url "$baseNoApi/notifications/$notifId" -Token $token1 }
  Write-Host "Notifications flow completed." -ForegroundColor Green
} catch { Write-Warning "Notification flow failed." }

# Admin checks
if ($AdminToken) {
  Write-Section "Admin Checks"
  try {
    $stats = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/stats" -Token $AdminToken
    Write-Host "Users: $($stats.collections.users) | Chats: $($stats.collections.chats) | Messages: $($stats.collections.messages)" -ForegroundColor Green
    $adminHealth = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/health" -Token $AdminToken
    Write-Host "Admin health: $($adminHealth.status)" -ForegroundColor Green
  } catch { Write-Warning "Admin endpoints failed." }
} else {
  Write-Host "AdminToken not provided; skipping admin checks." -ForegroundColor Yellow
}

# FCM tests (dry-run without real tokens)
Write-Section "FCM Send Test (dry-run)"
try {
  $send = Invoke-ApiJson -Method POST -Url "$FcmBaseUrl/send-notification" -Body @{ token = "DUMMY_TOKEN"; title = "E2E"; body = "Hello"; data = @{ type = "test" } }
  Write-Host "FCM send responded" -ForegroundColor Green
} catch { Write-Warning "FCM send failed (expected without real token)." }

# ngrok public URL smoke
Write-Section "ngrok Public URL"
try {
  $resp = Invoke-RestMethod -Method GET -Uri "$PublicNgrokUrl/health" -Headers @{ 'ngrok-skip-browser-warning' = 'true' }
  Write-Host "Public URL health: $($resp.status)" -ForegroundColor Green
} catch { Write-Warning "Public ngrok URL health check failed." }

Write-Host "`nFull E2E test completed." -ForegroundColor Green