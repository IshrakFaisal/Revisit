#include "peer_identity.h"
#include "pipe_transport.h"
#include <softpub.h>
#include <wincrypt.h>
#include <wintrust.h>
#include <vector>

namespace revisit {
std::wstring executable_path(DWORD process_id) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) return {};
  std::vector<wchar_t> buffer(32768);
  DWORD size = static_cast<DWORD>(buffer.size());
  const bool ok = QueryFullProcessImageNameW(process, 0, buffer.data(), &size) != FALSE;
  CloseHandle(process);
  return ok ? std::wstring(buffer.data(), size) : L"";
}
std::wstring sibling_executable(const wchar_t* name) {
  const auto own = executable_path(GetCurrentProcessId());
  const auto slash = own.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"" : own.substr(0, slash + 1) + name;
}
bool process_is_file(DWORD process_id, const std::wstring& expected) {
  const auto actual = executable_path(process_id);
  if (actual.empty() || expected.empty()) return false;
  HANDLE left = CreateFileW(actual.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    nullptr, OPEN_EXISTING, 0, nullptr);
  HANDLE right = CreateFileW(expected.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    nullptr, OPEN_EXISTING, 0, nullptr);
  BY_HANDLE_FILE_INFORMATION a{}, b{};
  const bool same = left != INVALID_HANDLE_VALUE && right != INVALID_HANDLE_VALUE &&
    GetFileInformationByHandle(left, &a) && GetFileInformationByHandle(right, &b) &&
    a.dwVolumeSerialNumber == b.dwVolumeSerialNumber &&
    a.nFileIndexHigh == b.nFileIndexHigh && a.nFileIndexLow == b.nFileIndexLow;
  if (left != INVALID_HANDLE_VALUE) CloseHandle(left);
  if (right != INVALID_HANDLE_VALUE) CloseHandle(right);
  return same;
}
bool supported_browser_publisher(const std::wstring& executable, const std::wstring& publisher) {
  if (_wcsicmp(executable.c_str(), L"chrome.exe") == 0) {
    return publisher == L"Google LLC" || publisher == L"Google Inc";
  }
  return _wcsicmp(executable.c_str(), L"brave.exe") == 0 && publisher == L"Brave Software, Inc.";
}
bool trusted_chrome_stdio() {
  // Authenticate the process that owns the browser's actual stdio pipes, not argv
  // or a spoofable parent PID. No caller-supplied PID is used.
  ULONG input = 0, output = 0;
  if (!GetNamedPipeServerProcessId(GetStdHandle(STD_INPUT_HANDLE), &input) ||
      !GetNamedPipeServerProcessId(GetStdHandle(STD_OUTPUT_HANDLE), &output) || input != output) return false;
  const auto path = executable_path(input);
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) return false;
  const auto executable = path.substr(slash + 1);
  if (_wcsicmp(executable.c_str(), L"chrome.exe") != 0 &&
      _wcsicmp(executable.c_str(), L"brave.exe") != 0) return false;
  WINTRUST_FILE_INFO file{};
  file.cbStruct = sizeof(file); file.pcwszFilePath = path.c_str();
  WINTRUST_DATA data{};
  data.cbStruct = sizeof(data); data.dwUIChoice = WTD_UI_NONE;
  data.fdwRevocationChecks = WTD_REVOKE_NONE;
  data.dwUnionChoice = WTD_CHOICE_FILE; data.pFile = &file;
  data.dwStateAction = WTD_STATEACTION_VERIFY;
  data.dwProvFlags = WTD_CACHE_ONLY_URL_RETRIEVAL;
  GUID policy = WINTRUST_ACTION_GENERIC_VERIFY_V2;
  bool trusted = WinVerifyTrust(nullptr, &policy, &data) == ERROR_SUCCESS;
  if (trusted) {
    auto provider = WTHelperProvDataFromStateData(data.hWVTStateData);
    auto signer = provider ? WTHelperGetProvSignerFromChain(provider, 0, FALSE, 0) : nullptr;
    wchar_t name[256]{};
    trusted = signer && signer->csCertChain > 0 &&
      CertGetNameStringW(signer->pasCertChain[0].pCert, CERT_NAME_SIMPLE_DISPLAY_TYPE, 0, nullptr, name, 256) > 1 &&
      supported_browser_publisher(executable, name);
  }
  data.dwStateAction = WTD_STATEACTION_CLOSE;
  WinVerifyTrust(nullptr, &policy, &data);
  return trusted;
}
bool trusted_desktop_client(HANDLE pipe) {
  ULONG pid = 0;
  return GetNamedPipeClientProcessId(pipe, &pid) && process_is_file(pid, sibling_executable(L"revisit_desktop_host.exe"));
}
bool trusted_desktop_server(HANDLE pipe) {
  ULONG pid = 0;
  return GetNamedPipeServerProcessId(pipe, &pid) && process_is_file(pid, sibling_executable(L"revisit.exe"));
}
std::wstring desktop_pipe_name() {
  const auto sid = user_sid();
  return sid.empty() ? L"" : L"\\\\.\\pipe\\Revisit.Context." + sid;
}
}
