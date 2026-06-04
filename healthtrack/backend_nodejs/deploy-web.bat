@echo off
echo ========================================
echo HealthTrack Web Deployment Script
echo ========================================

echo Step 1: Building Flutter web app...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter build failed
    exit /b 1
)

echo Step 2: Deploying to Vercel...
cd build\web
call vercel --prod

cd ..\..

echo ========================================
echo Deployment Complete!
echo ========================================
echo Your web app is now live on Vercel
echo ========================================