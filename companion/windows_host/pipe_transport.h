#pragma once
#include <windows.h>
#include <string>

namespace revisit {
std::wstring user_sid();
std::wstring pipe_name();
HANDLE create_receiver_pipe();
HANDLE create_receiver_pipe(const std::wstring& name);
bool connect_receiver(HANDLE pipe, DWORD timeout_ms);
bool transfer(HANDLE pipe, void* data, DWORD bytes, bool writing, DWORD timeout_ms = 2000);
bool receive_pipe_frame(HANDLE pipe, std::string& payload, DWORD timeout_ms = 2000);
bool send_pipe_frame(HANDLE pipe, const std::string& payload);
}  // namespace revisit
