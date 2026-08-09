# SentinelX Windows C++ Desktop Agent

The lightweight C++ Windows system security agent for **SentinelX**. Performs process inspection, unsigned binary audit, input hook monitoring simulation, and reports device security status to the SentinelX platform.

## Features
- Active Windows process inspection and memory audit.
- Flags unsigned executables and suspicious persistence hooks.
- Interfaces with the SentinelX Security Platform.

## How to Build & Run on Windows

1. Run `build_agent.bat` or compile with `g++`:
   ```cmd
   g++ -O2 sentinelx_agent.cpp -o sentinelx_agent.exe
   ```
2. Launch the agent:
   ```cmd
   sentinelx_agent.exe
   ```
