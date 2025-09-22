@echo off
echo Starting PhishWatch Pro Automated Testing...
echo.

REM Get dependencies
echo Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo Failed to get dependencies
    exit /b 1
)

echo.
echo Running automated test suite...
call dart run test_runner.dart

echo.
echo Test execution completed!
pause

