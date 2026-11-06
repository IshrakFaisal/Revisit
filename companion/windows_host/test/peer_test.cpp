#include "../peer_identity.h"
#include "../pipe_transport.h"
#include <iostream>
#include <stdexcept>
#include <future>
void check(bool condition) { if (!condition) throw std::runtime_error("peer identity assertion failed"); }
int main() {
  check(revisit::supported_browser_publisher(L"chrome.exe", L"Google LLC"));
  check(revisit::supported_browser_publisher(L"chrome.exe", L"Google Inc"));
  check(revisit::supported_browser_publisher(L"BRAVE.EXE", L"Brave Software, Inc."));
  check(!revisit::supported_browser_publisher(L"brave.exe", L"Google LLC"));
  check(!revisit::supported_browser_publisher(L"chrome.exe", L"Brave Software, Inc."));
  check(!revisit::supported_browser_publisher(L"other.exe", L"Brave Software, Inc."));
  check(!revisit::supported_browser_publisher(L"brave.exe", L""));
  const auto own = revisit::executable_path(GetCurrentProcessId());
  check(!own.empty());
  check(revisit::process_is_file(GetCurrentProcessId(), own));
  check(!revisit::process_is_file(GetCurrentProcessId(), revisit::sibling_executable(L"revisit_desktop_host.exe")));
  check(!revisit::process_is_file(0, own));
  check(!revisit::trusted_chrome_stdio());
  check(!revisit::trusted_desktop_client(INVALID_HANDLE_VALUE));
  check(!revisit::trusted_desktop_server(INVALID_HANDLE_VALUE));
  // A real same-user pipe connection is insufficient to impersonate either
  // production peer. Use a unique test pipe; never touch the live receiver.
  const auto name = revisit::desktop_pipe_name() + L".test." + std::to_wstring(GetCurrentProcessId());
  HANDLE server = revisit::create_receiver_pipe(name);
  check(server != INVALID_HANDLE_VALUE);
  auto receiving = std::async(std::launch::async, [server] {
    return revisit::connect_receiver(server, 2000) && !revisit::trusted_desktop_client(server);
  });
  HANDLE client = CreateFileW(name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
  check(client != INVALID_HANDLE_VALUE);
  check(!revisit::trusted_desktop_server(client));
  check(receiving.get());
  CloseHandle(client);
  DisconnectNamedPipe(server);
  CloseHandle(server);
  std::cout << "peer identity checks passed\n";
}
