@echo off
cd /d "C:\Users\Administrator\Documents\GitHub\soc-chat-app\scripts\.."
start /b "" "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" --dbpath "D:\soc-chat-data\MongoDB\data\db" --port 27017 --logpath "D:\soc-chat-data\MongoDB\log\mongodb.log"
