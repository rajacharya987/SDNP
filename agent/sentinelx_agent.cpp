#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>

// SentinelX Windows C++ Agent Simulator & System Security Inspector
struct ProcessInfo {
    std::string processName;
    int pid;
    bool isSigned;
    bool hasInputHook;
    std::string riskLevel;
};

void printBanner() {
    std::cout << "========================================================\n";
    std::cout << "          🛡️ SENTINELX WINDOWS C++ SECURITY AGENT       \n";
    std::cout << "========================================================\n";
    std::cout << " [System Protection Layer] Active & Monitoring\n";
    std::cout << " Mode: Process Inspection | Input Hook Monitor | Persistence Audit\n";
    std::cout << "========================================================\n\n";
}

std::vector<ProcessInfo> inspectProcesses() {
    std::vector<ProcessInfo> processes = {
        {"chrome.exe", 4120, true, false, "SAFE"},
        {"explorer.exe", 1084, true, false, "SAFE"},
        {"svchost.exe", 892, true, false, "SAFE"},
        {"sentinelx_agent.exe", 6200, true, false, "SAFE"},
        {"keyhook_sim.exe", 7812, false, true, "HIGH_RISK_SUSPICIOUS_HOOK"},
        {"unknown_temp_updater.exe", 9104, false, false, "WARN_UNSIGNED"}
    };
    return processes;
}

int main() {
    printBanner();

    std::cout << "[+] Initializing SentinelX Local Process & Hook Audit...\n";
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    std::cout << "[+] Scanning Active Memory Processes & Input Event Listeners...\n\n";
    
    std::vector<ProcessInfo> activeProcs = inspectProcesses();
    int highRiskCount = 0;

    std::cout << "------------------------------------------------------------------------\n";
    std::cout << " PID    | PROCESS NAME              | SIGNED  | HOOK DETECTED | STATUS   \n";
    std::cout << "------------------------------------------------------------------------\n";

    for (const auto& proc : activeProcs) {
        std::cout << " " << proc.pid << " \t| " 
                  << proc.processName << (proc.processName.length() < 16 ? "\t\t| " : "\t| ")
                  << (proc.isSigned ? "YES    | " : "NO (🚨)| ")
                  << (proc.hasInputHook ? "YES (🚨)      | " : "NO            | ")
                  << proc.riskLevel << "\n";
        
        if (proc.riskLevel.find("HIGH_RISK") != std::string::npos) {
            highRiskCount++;
        }
    }

    std::cout << "------------------------------------------------------------------------\n\n";
    
    std::cout << "========================================================\n";
    std::cout << " SENTINELX AGENT DIAGNOSTIC SUMMARY:\n";
    std::cout << " Total Inspected Processes : " << activeProcs.size() << "\n";
    std::cout << " High Risk Threat Processes : " << highRiskCount << "\n";
    std::cout << " Local Network Protection  : ACTIVE (127.0.0.1:8080)\n";
    std::cout << " Device Status             : PROTECTED\n";
    std::cout << "========================================================\n";

    return 0;
}
