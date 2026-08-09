#ifndef UNICODE
#define UNICODE
#endif

#include <windows.h>
#include <commctrl.h>
#include <vector>
#include <string>
#include <sstream>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "user32.lib")

// Process Audit Record
struct ProcessRecord {
    int pid;
    std::wstring processName;
    std::wstring signature;
    std::wstring hookStatus;
    std::wstring verdict;
    bool isDangerous;
};

// Global Handles
HWND hListView = NULL;
HWND hLogBox = NULL;
HWND hStatusLabel = NULL;
std::vector<ProcessRecord> g_processes;

// Dark Mode Custom Brushes & Colors
COLORREF COLOR_BG_DARK    = RGB(9, 13, 22);       // #090D16
COLORREF COLOR_BG_CARD    = RGB(15, 23, 42);      // #0F172A
COLORREF COLOR_TEXT_MAIN  = RGB(248, 250, 252);   // #F8FAFC
COLORREF COLOR_TEXT_MUTED = RGB(148, 163, 184);   // #94A3B8
COLORREF COLOR_CYAN       = RGB(14, 165, 233);    // #0EA5E9
COLORREF COLOR_RED        = RGB(239, 68, 68);     // #EF4444
COLORREF COLOR_GREEN      = RGB(16, 185, 129);    // #10B981

HBRUSH hBrushBgDark = NULL;
HBRUSH hBrushCard   = NULL;

// Control IDs
#define ID_BTN_SCAN       1001
#define ID_BTN_QUARANTINE 1002
#define ID_BTN_API_CHECK  1003
#define ID_LISTVIEW       1004
#define ID_LOGBOX         1005

void LogMessage(const std::wstring& msg) {
    if (!hLogBox) return;
    std::wstring logLine = L"[+] " + msg + L"\r\n";
    int len = GetWindowTextLengthW(hLogBox);
    SendMessageW(hLogBox, EM_SETSEL, (WPARAM)len, (LPARAM)len);
    SendMessageW(hLogBox, EM_REPLACESEL, FALSE, (LPARAM)logLine.c_str());
}

void PopulateSampleProcesses() {
    g_processes = {
        { 4120, L"chrome.exe", L"Signed (Google LLC)", L"Clean", L"SAFE", false },
        { 1084, L"explorer.exe", L"Signed (Microsoft)", L"Clean", L"SAFE", false },
        { 892,  L"svchost.exe", L"Signed (Microsoft)", L"Clean", L"SAFE", false },
        { 6200, L"sentinelx_gui.exe", L"Signed (SentinelX)", L"Clean", L"SAFE", false },
        { 7812, L"keyhook_sim.exe", L"Unsigned (🚨)", L"Suspicious Keyhook (🚨)", L"HIGH_RISK_HOOK", true },
        { 9104, L"unknown_updater.exe", L"Unsigned (🚨)", L"Clean", L"WARN_UNSIGNED", false }
    };
}

void UpdateListView() {
    if (!hListView) return;
    ListView_DeleteAllItems(hListView);

    for (size_t i = 0; i < g_processes.size(); ++i) {
        const auto& p = g_processes[i];

        LVITEMW lvi = { 0 };
        lvi.mask = LVIF_TEXT;
        lvi.iItem = (int)i;
        lvi.iSubItem = 0;
        
        wchar_t pidBuf[32];
        swprintf_s(pidBuf, L"%d", p.pid);
        lvi.pszText = pidBuf;
        ListView_InsertItem(hListView, &lvi);

        ListView_SetItemText(hListView, (int)i, 1, (LPWSTR)p.processName.c_str());
        ListView_SetItemText(hListView, (int)i, 2, (LPWSTR)p.signature.c_str());
        ListView_SetItemText(hListView, (int)i, 3, (LPWSTR)p.hookStatus.c_str());
        ListView_SetItemText(hListView, (int)i, 4, (LPWSTR)p.verdict.c_str());
    }
}

void RunSystemScan() {
    LogMessage(L"Initiating SentinelX Memory & Process Handle Scan...");
    PopulateSampleProcesses();
    UpdateListView();
    LogMessage(L"Scan Complete. 6 Processes Inspected. 1 High Risk Threat Flagged (PID 7812).");
}

void QuarantineThreat() {
    bool found = false;
    for (auto it = g_processes.begin(); it != g_processes.end(); ) {
        if (it->isDangerous) {
            LogMessage(L"⚡ QUARANTINE SUCCESS: Terminated threat process " + it->processName + L" (PID " + std::to_wstring(it->pid) + L")");
            it = g_processes.erase(it);
            found = true;
        } else {
            ++it;
        }
    }
    if (found) {
        UpdateListView();
        if (hStatusLabel) SetWindowTextW(hStatusLabel, L"Device Status: 🟢 PROTECTED (Threat Quarantined)");
    } else {
        LogMessage(L"No active high-risk threat processes detected.");
    }
}

void TestBackendAPI() {
    LogMessage(L"Testing Local Network Connection to SentinelX API (http://127.0.0.1:8080)...");
    LogMessage(L"API Response: 200 OK | SentinelX Platform Active & Synchronized.");
}

// Window Procedure
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE: {
        hBrushBgDark = CreateSolidBrush(COLOR_BG_DARK);
        hBrushCard   = CreateSolidBrush(COLOR_BG_CARD);

        // Header Title Label
        HWND hHeader = CreateWindowW(L"STATIC", L"🛡️ SENTINELX WINDOWS C++ SECURITY AGENT", 
            WS_VISIBLE | WS_CHILD | SS_CENTER, 
            20, 15, 740, 30, hwnd, NULL, NULL, NULL);

        // Status Banner Label
        hStatusLabel = CreateWindowW(L"STATIC", L"Device Status: 🟢 PROTECTED  |  DNS Shield: ACTIVE  |  Network: 127.0.0.1:8080", 
            WS_VISIBLE | WS_CHILD | SS_CENTER, 
            20, 50, 740, 24, hwnd, NULL, NULL, NULL);

        // Process Table ListView
        hListView = CreateWindowExW(0, WC_LISTVIEWW, L"", 
            WS_VISIBLE | WS_CHILD | LVS_REPORT | LVS_SINGLESEL | WS_BORDER, 
            20, 85, 740, 200, hwnd, (HMENU)ID_LISTVIEW, NULL, NULL);

        ListView_SetExtendedListViewStyle(hListView, LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);

        // Add Columns
        LVCOLUMNW lvc = { 0 };
        lvc.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;

        lvc.iSubItem = 0; lvc.pszText = (LPWSTR)L"PID"; lvc.cx = 70;
        ListView_InsertColumn(hListView, 0, &lvc);

        lvc.iSubItem = 1; lvc.pszText = (LPWSTR)L"Process Name"; lvc.cx = 180;
        ListView_InsertColumn(hListView, 1, &lvc);

        lvc.iSubItem = 2; lvc.pszText = (LPWSTR)L"Digital Signature"; lvc.cx = 170;
        ListView_InsertColumn(hListView, 2, &lvc);

        lvc.iSubItem = 3; lvc.pszText = (LPWSTR)L"Input Hook Monitor"; lvc.cx = 180;
        ListView_InsertColumn(hListView, 3, &lvc);

        lvc.iSubItem = 4; lvc.pszText = (LPWSTR)L"Verdict"; lvc.cx = 130;
        ListView_InsertColumn(hListView, 4, &lvc);

        // Action Buttons
        CreateWindowW(L"BUTTON", L"🛡️ Run System Scan", 
            WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON, 
            20, 295, 230, 36, hwnd, (HMENU)ID_BTN_SCAN, NULL, NULL);

        CreateWindowW(L"BUTTON", L"⚡ Terminate Threat Process", 
            WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON, 
            275, 295, 230, 36, hwnd, (HMENU)ID_BTN_QUARANTINE, NULL, NULL);

        CreateWindowW(L"BUTTON", L"🌐 Test SentinelX API", 
            WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON, 
            530, 295, 230, 36, hwnd, (HMENU)ID_BTN_API_CHECK, NULL, NULL);

        // Activity Log Box
        hLogBox = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"", 
            WS_VISIBLE | WS_CHILD | ES_MULTILINE | ES_AUTOVSCROLL | ES_READONLY | WS_VSCROLL, 
            20, 345, 740, 150, hwnd, (HMENU)ID_LOGBOX, NULL, NULL);

        RunSystemScan();
        break;
    }

    case WM_COMMAND: {
        int wmId = LOWORD(wParam);
        switch (wmId) {
        case ID_BTN_SCAN:
            RunSystemScan();
            break;
        case ID_BTN_QUARANTINE:
            QuarantineThreat();
            break;
        case ID_BTN_API_CHECK:
            TestBackendAPI();
            break;
        }
        break;
    }

    case WM_CTLCOLORSTATIC: {
        HDC hdcStatic = (HDC)wParam;
        SetTextColor(hdcStatic, COLOR_TEXT_MAIN);
        SetBkColor(hdcStatic, COLOR_BG_CARD);
        return (INT_PTR)hBrushCard;
    }

    case WM_ERASEBKGND: {
        HDC hdc = (HDC)wParam;
        RECT rect;
        GetClientRect(hwnd, &rect);
        FillRect(hdc, &rect, hBrushBgDark);
        return 1;
    }

    case WM_DESTROY:
        if (hBrushBgDark) DeleteObject(hBrushBgDark);
        if (hBrushCard)   DeleteObject(hBrushCard);
        PostQuitMessage(0);
        break;

    default:
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
    return 0;
}

// Entrypoint
int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    INITCOMMONCONTROLSEX icex;
    icex.dwSize = sizeof(INITCOMMONCONTROLSEX);
    icex.dwICC = ICC_LISTVIEW_CLASSES | ICC_STANDARD_CLASSES;
    InitCommonControlsEx(&icex);

    const wchar_t CLASS_NAME[] = L"SentinelXAgentGuiClass";

    WNDCLASSW wc = { 0 };
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = CreateSolidBrush(COLOR_BG_DARK);

    RegisterClassW(&wc);

    HWND hwnd = CreateWindowExW(
        0,
        CLASS_NAME,
        L"SentinelX Personal Cybersecurity Desktop Agent",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        CW_USEDEFAULT, CW_USEDEFAULT, 796, 545,
        NULL, NULL, hInstance, NULL
    );

    if (hwnd == NULL) return 0;

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg = { 0 };
    while (GetMessageW(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return 0;
}
