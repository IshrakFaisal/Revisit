#include "pipe_transport.h"
#include "protocol.h"
#include <sddl.h>
#include <sstream>
#include <vector>

namespace revisit {
std::wstring user_sid() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return {};
  DWORD bytes = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &bytes);
  std::vector<unsigned char> buffer(bytes);
  const bool ok = GetTokenInformation(token, TokenUser, buffer.data(), bytes, &bytes) != FALSE;
  CloseHandle(token);
  if (!ok) return {};
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid)) return {};
  std::wstring result(sid);
  LocalFree(sid);
  return result;
}
std::wstring pipe_name() {
  const auto sid = user_sid();
  return sid.empty() ? L"" : L"\\\\.\\pipe\\Revisit.ContextProof." + sid;
}
HANDLE create_receiver_pipe() { return create_receiver_pipe(pipe_name()); }
HANDLE create_receiver_pipe(const std::wstring& name) {
  const auto sid = user_sid();
  if (sid.empty() || name.empty()) return INVALID_HANDLE_VALUE;
  // Explicit protected DACL: only this user. Never fall back to default ACLs.
  const auto descriptor = L"D:P(A;;GA;;;" + sid + L")";
  PSECURITY_DESCRIPTOR security = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(descriptor.c_str(), SDDL_REVISION_1, &security, nullptr)) return INVALID_HANDLE_VALUE;
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), security, FALSE};
  HANDLE pipe = CreateNamedPipeW(name.c_str(), PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
    PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS, 1, kMaxMessage + 4, kMaxMessage + 4, 2000, &attributes);
  LocalFree(security);
  return pipe;
}
namespace {
bool finish(HANDLE pipe, OVERLAPPED& op, bool started, DWORD error, DWORD timeout_ms, DWORD& done) {
  bool success = started;
  if (!started && error == ERROR_IO_PENDING) {
    success = WaitForSingleObject(op.hEvent, timeout_ms) == WAIT_OBJECT_0 && GetOverlappedResult(pipe, &op, &done, FALSE);
    if (!success) { CancelIoEx(pipe, &op); GetOverlappedResult(pipe, &op, &done, TRUE); }
  } else if (started) {
    success = GetOverlappedResult(pipe, &op, &done, FALSE) != FALSE;
  }
  CloseHandle(op.hEvent);
  return success;
}
}  // namespace
bool connect_receiver(HANDLE pipe, DWORD timeout_ms) {
  OVERLAPPED op{};
  op.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!op.hEvent) return false;
  const bool started = ConnectNamedPipe(pipe, &op) != FALSE;
  const DWORD error = started ? ERROR_SUCCESS : GetLastError();
  if (error == ERROR_PIPE_CONNECTED) { CloseHandle(op.hEvent); return true; }
  DWORD done = 0;
  return finish(pipe, op, started, error, timeout_ms, done);
}
bool transfer(HANDLE pipe, void* data, DWORD bytes, bool writing, DWORD timeout_ms) {
  DWORD offset = 0;
  const ULONGLONG deadline = GetTickCount64() + timeout_ms;
  while (offset < bytes) {
    const auto now = GetTickCount64();
    if (now >= deadline) return false;
    OVERLAPPED op{};
    op.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!op.hEvent) return false;
    DWORD done = 0;
    auto* position = static_cast<char*>(data) + offset;
    const bool started = (writing ? WriteFile(pipe, position, bytes - offset, nullptr, &op) : ReadFile(pipe, position, bytes - offset, nullptr, &op)) != FALSE;
    const DWORD error = started ? ERROR_SUCCESS : GetLastError();
    if (!finish(pipe, op, started, error, static_cast<DWORD>(deadline - now), done) || !done) return false;
    offset += done;
  }
  return true;
}
bool receive_pipe_frame(HANDLE pipe, std::string& payload, DWORD timeout_ms) {
  unsigned char header[4];
  if (!transfer(pipe, header, 4, false, timeout_ms)) return false;
  std::uint32_t length = 0;
  for (unsigned int i = 0; i < 4; ++i) length |= static_cast<std::uint32_t>(header[i]) << (i * 8);
  if (!length || length > kMaxMessage) return false;
  payload.resize(length);
  return transfer(pipe, payload.data(), length, false, timeout_ms);
}
bool send_pipe_frame(HANDLE pipe, const std::string& payload) {
  auto data = frame(payload);
  return !data.empty() && transfer(pipe, data.data(), static_cast<DWORD>(data.size()), true);
}
}  // namespace revisit
