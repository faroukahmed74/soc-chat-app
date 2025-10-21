@echo off 
cd /d "C:\Users\Administrator\Documents\GitHub\soc-chat-app\scripts\.." 
start /b "" "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" --dbpath "data\db" --port 27017 --logpath "C:\Users\Administrator\Documents\GitHub\soc-chat-app\scripts\..\scripts\run\mongodb.log" 
