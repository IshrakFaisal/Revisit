#pragma once
#include <windows.h>
#include <string>
namespace revisit {
std::wstring executable_path(DWORD process_id);
std::wstring sibling_executable(const wchar_t* name);
bool process_is_file(DWORD process_id, const std::wstring& expected);
bool supported_browser_publisher(const std::wstring& executable, const std::wstring& publisher);
bool trusted_chrome_stdio();
bool trusted_desktop_client(HANDLE pipe);
bool trusted_desktop_server(HANDLE pipe);
std::wstring desktop_pipe_name();
}
