# Add E:\Programs to system PATH so ngrok and other tools are found
$targetPath = "E:\Programs"
$scope = "Machine"

$currentPath = [Environment]::GetEnvironmentVariable("Path", $scope)
if ($currentPath -and $currentPath -like "*$targetPath*") {
    Write-Host "E:\Programs is already in system PATH" -ForegroundColor Green
} else {
    $newPath = if ($currentPath) { "$targetPath;$currentPath" } else { $targetPath }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
    Write-Host "Added E:\Programs to system PATH (ngrok will be found by services manager)" -ForegroundColor Green
}

# Refresh current session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
if (Get-Command ngrok -ErrorAction SilentlyContinue) {
    Write-Host "ngrok found: $(Get-Command ngrok | Select-Object -ExpandProperty Source)" -ForegroundColor Green
} else {
    Write-Host "Note: Open a new terminal for PATH changes to take effect" -ForegroundColor Yellow
}
