# Add E:\flutter\bin to system PATH
$targetPath = "E:\flutter\bin"
$scope = "Machine"

$currentPath = [Environment]::GetEnvironmentVariable("Path", $scope)
if ($currentPath -and $currentPath -like "*$targetPath*") {
    Write-Host "E:\flutter\bin is already in PATH" -ForegroundColor Green
} else {
    $newPath = if ($currentPath) { "$currentPath;$targetPath" } else { $targetPath }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
    Write-Host "Added E:\flutter\bin to system PATH" -ForegroundColor Green
}

$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
& "$targetPath\flutter.bat" --version
