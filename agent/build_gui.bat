@echo off
echo Building SentinelX Windows C++ Desktop GUI Application...
where g++ >nul 2>nul
if %errorlevel% equ 0 (
    g++ -O2 sentinelx_gui.cpp -o sentinelx_gui.exe -mwindows -lgdi32 -luser32 -lcomctl32
    echo Build Successful: sentinelx_gui.exe
    goto end
)

where cl >nul 2>nul
if %errorlevel% equ 0 (
    cl /EHsc sentinelx_gui.cpp /link user32.lib gdi32.lib comctl32.lib /OUT:sentinelx_gui.exe
    echo Build Successful: sentinelx_gui.exe
    goto end
)

echo Warning: g++ or MSVC cl compiler not found in PATH.
:end
pause
