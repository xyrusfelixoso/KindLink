@echo off
set "PROJECT_DIR=%~dp0Humania"

start "KindLink App Web" cmd /k "cd /d ""%PROJECT_DIR%"" && flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8081 --dart-define=ADMIN_WEB=false"
start "KindLink Admin Web" cmd /k "cd /d ""%PROJECT_DIR%"" && flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080 --dart-define=ADMIN_WEB=true"

echo Starting KindLink app and admin servers...
echo App:   http://127.0.0.1:8081
echo Admin: http://127.0.0.1:8080
