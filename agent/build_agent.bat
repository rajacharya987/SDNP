@echo off
echo Building SentinelX Windows C++ Agent...
where g++ >nul 2>nul
if %errorlevel% equ 0 (
    g++ -O2 sentinelx_agent.cpp -o sentinelx_agent.exe
    echo Build Successful: sentinelx_agent.exe
    goto end
)

where cl >nul 2>nul
if %errorlevel% equ 0 (
    cl /EHsc sentinelx_agent.cpp /Fesentinelx_agent.exe
    echo Build Successful: sentinelx_agent.exe
    goto end
)

echo Warning: g++ or MSVC cl compiler not found in PATH.
:end
pause
