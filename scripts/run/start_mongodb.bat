@echo off
REM SOC Chat App - Start MongoDB on port 27017
REM Tries: MongoDB 8.2, then 6.0. Uses dbpath D:\soc-chat-data\MongoDB\data\db
cd /d "%~dp0..\.."

set "DBPATH=D:\soc-chat-data\MongoDB\data\db"
set "LOGPATH=D:\soc-chat-data\MongoDB\log\mongodb.log"

if exist "C:\Program Files\MongoDB\Server\8.2\bin\mongod.exe" (
  echo Starting MongoDB 8.2 with dbpath %DBPATH%...
  start /b "" "C:\Program Files\MongoDB\Server\8.2\bin\mongod.exe" --dbpath "%DBPATH%" --port 27017 --logpath "%LOGPATH%" --logappend --bind_ip 127.0.0.1
  goto :done
)
if exist "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" (
  echo Starting MongoDB 6.0 with dbpath %DBPATH%...
  start /b "" "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" --dbpath "%DBPATH%" --port 27017 --logpath "%LOGPATH%" --logappend
  goto :done
)

echo ERROR: mongod.exe not found. Install MongoDB 6.0 or 8.2, or use Docker: scripts\run\start_mongodb_docker.ps1
exit /b 1

:done
echo MongoDB start requested. Check port 27017: netstat -an ^| findstr 27017
exit /b 0
