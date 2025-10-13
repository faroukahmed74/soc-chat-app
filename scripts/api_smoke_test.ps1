param(
  [string]$ApiBaseUrl = "http://localhost:3003/api",
  [string]$AdminToken = ""
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
    [string]$Caption = 'Smoke test upload',
    [string]$FilePath
  )
  # Use .NET HttpClient multipart upload (PowerShell-native)
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

Write-Section "Health Check"
$health = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/health"
Write-Host "Status: $($health.status)" -ForegroundColor Green

Write-Section "Register & Login Users"
$suffix = (Get-Date).ToString('yyyyMMddHHmmss')
$user1Email = "smoke1+$suffix@example.com"
$user2Email = "smoke2+$suffix@example.com"

$reg1 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/register" -Body @{ email = $user1Email; password = "Password123!"; name = "Smoke User 1" }
$reg2 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/register" -Body @{ email = $user2Email; password = "Password123!"; name = "Smoke User 2" }
Write-Host "Registered: $($reg1.user.id) and $($reg2.user.id)" -ForegroundColor Green

$login1 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/login" -Body @{ email = $user1Email; password = "Password123!" }
$login2 = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/auth/login" -Body @{ email = $user2Email; password = "Password123!" }
$token1 = $login1.token
$token2 = $login2.token
$user1Id = $login1.user.id
$user2Id = $login2.user.id
Write-Host "Logged in. Tokens acquired." -ForegroundColor Green

Write-Section "Auth User"
try {
  $me = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/auth/user" -Token $token1
  Write-Host "Authed user: $($me.user.id) ($($me.user.email))" -ForegroundColor Green
} catch {
  Write-Warning "Auth user endpoint unavailable; continuing."
}

Write-Section "Create Chat"
$chatCreate = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/chats" -Body @{ name = "Smoke Chat"; members = @($user1Id, $user2Id) } -Token $token1
$chatId = if ($chatCreate.chat) { $chatCreate.chat.id } else { $chatCreate.id }
Write-Host "Chat created: $chatId" -ForegroundColor Green

Write-Section "List Chats"
$chats = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/chats" -Token $token1
$chatCount = if ($chats.chats) { $chats.chats.Count } else { $chats.Count }
Write-Host "Chats count: $chatCount" -ForegroundColor Green

Write-Section "Send Message"
# Server may mount messages at '/messages' or '/api/messages'. Try API path first, then fallback.
$baseNoApi = $ApiBaseUrl -replace '/api$',''
try {
  $msgCreate = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/messages" -Body @{ chatId = $chatId; content = "Hello from smoke test"; messageType = "text" } -Token $token1
} catch {
  Write-Warning "Primary message POST failed; trying non-API path."
  $msgCreate = Invoke-ApiJson -Method POST -Url "$baseNoApi/messages" -Body @{ chatId = $chatId; content = "Hello from smoke test"; messageType = "text" } -Token $token1
}
$messageId = if ($msgCreate.messageData) { $msgCreate.messageData.id } else { $msgCreate.id }
Write-Host "Message sent: $messageId" -ForegroundColor Green

Write-Section "List Messages"
# GET messages by chat: '/messages/:chatId' (or '/api/messages/:chatId'). Try API path first.
try {
  $msgs = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/messages/$($chatId)?limit=10" -Token $token1
} catch {
  Write-Warning "Primary message GET failed; trying non-API path."
  $msgs = Invoke-ApiJson -Method GET -Url "$baseNoApi/messages/$($chatId)?limit=10" -Token $token1
}
$msgCount = if ($msgs.messages) { $msgs.messages.Count } else { $msgs.Count }
Write-Host "Messages returned: $msgCount" -ForegroundColor Green

# Optional: Update/Delete via message routes (may be unavailable depending on server build)
try {
  Write-Section "Update Message"
  $msgUpdate = Invoke-ApiJson -Method PUT -Url "$ApiBaseUrl/messages/$messageId" -Body @{ content = "Updated content" } -Token $token1
  $updatedId = if ($msgUpdate.messageData) { $msgUpdate.messageData.id } else { $msgUpdate.id }
  Write-Host "Message updated: $updatedId" -ForegroundColor Green

  Write-Section "Delete Message"
  $msgDelete = Invoke-ApiJson -Method DELETE -Url "$ApiBaseUrl/messages/$messageId" -Token $token1
  Write-Host "Message deleted." -ForegroundColor Green
} catch {
  Write-Warning "Message update/delete endpoints not available; continuing."
}

Write-Section "Notifications"
try {
$baseNoApi = $ApiBaseUrl -replace '/api$', ''
try {
  $notifCreate = Invoke-ApiJson -Method POST -Url "$ApiBaseUrl/notifications" -Body @{ userId = $user1Id; type = "info"; title = "Smoke Test"; message = "Notification test" } -Token $token1
} catch {
  Write-Warning "Primary notification POST failed; trying non-API path."
  $notifCreate = Invoke-ApiJson -Method POST -Url "$baseNoApi/notifications" -Body @{ userId = $user1Id; type = "info"; title = "Smoke Test"; message = "Notification test" } -Token $token1
}
$notifId = if ($notifCreate.notification) { $notifCreate.notification.id } else { $notifCreate.id }
Write-Host "Notification created: $notifId" -ForegroundColor Green

try {
  $notifs = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/notifications?unreadOnly=true&limit=5" -Token $token1
} catch {
  Write-Warning "Primary notification GET failed; trying non-API path."
  $notifs = Invoke-ApiJson -Method GET -Url "$baseNoApi/notifications?unreadOnly=true&limit=5" -Token $token1
}
$notifCount = if ($notifs.notifications) { $notifs.notifications.Count } else { $notifs.Count }
Write-Host "Unread notifications: $notifCount" -ForegroundColor Green

try {
  $markRead = Invoke-ApiJson -Method PUT -Url "$ApiBaseUrl/notifications/$notifId/read" -Token $token1
} catch {
  Write-Warning "Primary mark read failed; trying non-API path."
  $markRead = Invoke-ApiJson -Method PUT -Url "$baseNoApi/notifications/$notifId/read" -Token $token1
}
Write-Host "Marked read: $notifId" -ForegroundColor Green

try {
  $markAll = Invoke-ApiJson -Method PUT -Url "$ApiBaseUrl/notifications/read-all" -Token $token1
} catch {
  Write-Warning "Primary mark all failed; trying non-API path."
  $markAll = Invoke-ApiJson -Method PUT -Url "$baseNoApi/notifications/read-all" -Token $token1
}
Write-Host "Marked all read: $($markAll.updatedCount) updated" -ForegroundColor Green

try {
  $notifDelete = Invoke-ApiJson -Method DELETE -Url "$ApiBaseUrl/notifications/$notifId" -Token $token1
} catch {
  Write-Warning "Primary notification delete failed; trying non-API path."
  $notifDelete = Invoke-ApiJson -Method DELETE -Url "$baseNoApi/notifications/$notifId" -Token $token1
}
Write-Host "Notification deleted." -ForegroundColor Green

} catch { Write-Warning "Notification tests failed; continuing." }

Write-Section "Media Upload"
$tempDir = Join-Path $env:TEMP "soc-chat-smoke"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$tempFile = Join-Path $tempDir "smoke-upload.txt"
"Hello media" | Out-File -FilePath $tempFile -Encoding UTF8

$uploadResp = Upload-Media -UploadUrl "$ApiBaseUrl/media/upload" -Token $token1 -ChatId $chatId -Type 'document' -Caption 'Smoke' -FilePath $tempFile
Write-Host "Uploaded: $($uploadResp.fileName) -> $($uploadResp.mediaUrl)" -ForegroundColor Green

if ($AdminToken) {
  Write-Section "Admin: Stats/Users/Chats/Messages/Health"
  $adminStats = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/stats" -Token $AdminToken
  Write-Host "Users: $($adminStats.collections.users), Chats: $($adminStats.collections.chats), Messages: $($adminStats.collections.messages)" -ForegroundColor Green

  $adminUsers = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/users?limit=5" -Token $AdminToken
  Write-Host "Admin users page size: $($adminUsers.pagination.limit)" -ForegroundColor Green

  $adminChats = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/chats?limit=5" -Token $AdminToken
  Write-Host "Admin chats page size: $($adminChats.pagination.limit)" -ForegroundColor Green

  $adminMsgs = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/messages?limit=5" -Token $AdminToken
  Write-Host "Admin messages page size: $($adminMsgs.pagination.limit)" -ForegroundColor Green

  $adminHealth = Invoke-ApiJson -Method GET -Url "$ApiBaseUrl/admin/health" -Token $AdminToken
  Write-Host "Admin health: $($adminHealth.status)" -ForegroundColor Green
} else {
  Write-Host "AdminToken not provided; skipping admin endpoint tests." -ForegroundColor Yellow
}

Write-Host "`nSmoke test completed successfully." -ForegroundColor Green