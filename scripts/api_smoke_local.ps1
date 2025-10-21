Param(
  [string]$BaseUrl = 'http://localhost:3003'
)

$ErrorActionPreference = 'Stop'

function Ensure-User {
  Param([string]$Email,[string]$Password,[string]$Name)
  $headers = @{ 'Content-Type'='application/json' }
  try {
    return Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/login" -Headers $headers -Body (@{ email=$Email; password=$Password } | ConvertTo-Json)
  } catch {
    return Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/register" -Headers $headers -Body (@{ email=$Email; password=$Password; name=$Name } | ConvertTo-Json)
  }
}

Write-Host "Health check: $BaseUrl/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/health"
Write-Host "Health: $($health|ConvertTo-Json)"

Write-Host "Auth: ensuring two users"
$userA = Ensure-User 'test.a@example.com' 'Password123!' 'Test A'
$userB = Ensure-User 'test.b@example.com' 'Password123!' 'Test B'
Write-Host "A: $($userA.user.id)  B: $($userB.user.id)"

$authA = @{ 'Authorization' = "Bearer $($userA.token)"; 'Content-Type'='application/json' }
$authB = @{ 'Authorization' = "Bearer $($userB.token)"; 'Content-Type'='application/json' }

Write-Host "Create private chat"
$privateChat = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/chats" -Headers $authA -Body (@{ type='private'; name='Smoke Private'; members=@($userA.user.id,$userB.user.id) } | ConvertTo-Json)
$privateChatId = ($privateChat.chat.id).ToString().Trim()
Write-Host "Private chat: $privateChatId"
Write-Host "ChatId debug: [$privateChatId] Len=$($privateChatId.Length)"

Write-Host "Verify chat accessible"
$chatGet = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/chats/$privateChatId" -Headers $authA
Write-Host "Chat name: $($chatGet.chat.name)"

Write-Host "Send messages (A,B)"
$sendA = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/messages" -Headers $authA -Body (@{ chatId=$privateChatId; content='hello from A'; type='text' } | ConvertTo-Json)
$sendB = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/messages" -Headers $authB -Body (@{ chatId=$privateChatId; content='hello from B'; type='text' } | ConvertTo-Json)
$msgAId = $sendA.messageData.id
$msgBId = $sendB.messageData.id
Write-Host "Message IDs: A=$msgAId B=$msgBId"

Write-Host "Fetch messages (list)"
Write-Host "DEBUG URL: $BaseUrl/api/messages/${privateChatId}?limit=10&page=1"
$list = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/messages/${privateChatId}?limit=10&page=1" -Headers $authA
Write-Host "Messages count: $($list.messages.Count)"

Write-Host "Update and delete messages"
Invoke-RestMethod -Method Put -Uri "$BaseUrl/api/messages/$msgAId" -Headers $authA -Body (@{ content='edited by A' } | ConvertTo-Json) | Out-Null
Invoke-RestMethod -Method Delete -Uri "$BaseUrl/api/messages/$msgBId" -Headers $authB | Out-Null

Write-Host "Mark messages as read"
$mark = Invoke-RestMethod -Method Patch -Uri "$BaseUrl/api/messages/$privateChatId/read" -Headers $authA -Body (@{ messageIds=@($msgAId) } | ConvertTo-Json)
Write-Host "Marked read count: $($mark.updatedCount)"

Write-Host "Fetch chat lastMessage"
$chatAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/chats/$privateChatId" -Headers $authA
Write-Host "LastMessage: $($chatAfter.chat.lastMessage.content)"

Write-Host "List users"
$users = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/users" -Headers $authA
Write-Host "Users count: $($users.Count)"

Write-Host "Update user status (optional)"
try {
  Invoke-RestMethod -Method Patch -Uri "$BaseUrl/api/users/$($userA.user.id)" -Headers $authA -Body (@{ status='online' } | ConvertTo-Json) | Out-Null
} catch {
  Write-Host "Skipping status update: $($_.Exception.Message)"
}
Write-Host "Status updated for A"

Write-Host "Smoke test OK"