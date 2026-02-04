# Add E:\Programs to system PATH so ngrok is available
$targetPath = "E:\Programs"
$scope = "Machine"  # System-wide (all users)

$currentPath = [Environment]::GetEnvironmentVariable("Path", $scope)
if ($currentPath -and $currentPath -like "*$targetPath*") {
    Write-Host "E:\Programs is already in PATH" -ForegroundColor Green
} else {
    $newPath = if ($currentPath) { "$currentPath;$targetPath" } else { $targetPath }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
    Write-Host "Added E:\Programs to system PATH ($scope)" -ForegroundColor Green
}

# Refresh current session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
Write-Host "Verify: ngrok version" -ForegroundColor Cyan
& "$targetPath\ngrok.exe" version
