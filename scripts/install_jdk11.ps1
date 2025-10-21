$ErrorActionPreference = 'Stop'

$zipUrl = 'https://aka.ms/download-jdk/microsoft-jdk-11.0.23-windows-x64.zip'
$dest = 'C:\\tools\\jdk11'

Write-Host "Ensuring destination directory at $dest"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$jdkDir = Get-ChildItem -Directory $dest | Where-Object { $_.Name -like 'jdk-*' -or $_.Name -like 'jdk-11*' -or $_.Name -like 'microsoft*' } | Select-Object -First 1
if (-not $jdkDir) {
  $zipPath = Join-Path $dest 'jdk11.zip'
  Write-Host "Downloading JDK 11 ZIP from $zipUrl to $zipPath"
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

  Write-Host "Expanding archive to $dest"
  Expand-Archive -Path $zipPath -DestinationPath $dest -Force

  $jdkDir = Get-ChildItem -Directory $dest | Where-Object { $_.Name -like 'jdk-*' -or $_.Name -like 'jdk-11*' -or $_.Name -like 'microsoft*' } | Select-Object -First 1
  if (-not $jdkDir) { throw 'JDK unzip directory not found' }
}

$env:JAVA_HOME = $jdkDir.FullName
Write-Host "JAVA_HOME set to $($env:JAVA_HOME)"

& "$env:JAVA_HOME\\bin\\java.exe" -version