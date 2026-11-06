#include "notification_identity.h"
#include <windows.h>
#include <shlobj.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/client.h>
#include <stdexcept>
#include <vector>

namespace revisit {
using Microsoft::WRL::ComPtr;
namespace {
void Check(HRESULT hr) { if (FAILED(hr)) throw std::runtime_error("Windows shortcut operation failed"); }
bool SameFile(const std::wstring& a, const std::wstring& b) {
  HANDLE left = CreateFileW(a.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, 0, nullptr);
  HANDLE right = CreateFileW(b.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, 0, nullptr);
  BY_HANDLE_FILE_INFORMATION x{}, y{};
  const bool same = left != INVALID_HANDLE_VALUE && right != INVALID_HANDLE_VALUE && GetFileInformationByHandle(left, &x) && GetFileInformationByHandle(right, &y) && x.dwVolumeSerialNumber == y.dwVolumeSerialNumber && x.nFileIndexHigh == y.nFileIndexHigh && x.nFileIndexLow == y.nFileIndexLow;
  if(left != INVALID_HANDLE_VALUE) CloseHandle(left);
  if(right != INVALID_HANDLE_VALUE) CloseHandle(right);
  return same;
}
ComPtr<IShellLinkW> Link() {
  ComPtr<IShellLinkW> link;
  Check(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link)));
  return link;
}
}
std::wstring notification_shortcut() {
  PWSTR programs = nullptr;
  Check(SHGetKnownFolderPath(FOLDERID_Programs, 0, nullptr, &programs));
  std::wstring path(programs);
  CoTaskMemFree(programs);
  return path + L"\\Revisit.lnk";
}
bool notification_configured(const std::wstring& executable) {
  try {
    auto link = Link();
    ComPtr<IPersistFile> file; Check(link.As(&file));
    Check(file->Load(notification_shortcut().c_str(), STGM_READ));
    std::vector<wchar_t> target(32768);
    Check(link->GetPath(target.data(), static_cast<int>(target.size()), nullptr, SLGP_RAWPATH));
    if (!SameFile(target.data(), executable)) return false;
    ComPtr<IPropertyStore> properties; Check(link.As(&properties));
    PROPVARIANT value{}; Check(properties->GetValue(PKEY_AppUserModel_ID, &value));
    const bool valid = value.vt == VT_LPWSTR && value.pwszVal && std::wstring(value.pwszVal) == kNotificationAppId;
    PropVariantClear(&value);
    return valid;
  } catch (...) { return false; }
}
void install_notification_shortcut(const std::wstring& executable) {
  const auto path = notification_shortcut();
  if (GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
    if (notification_configured(executable)) return;
    throw std::runtime_error("Existing Revisit shortcut does not belong to this bundle; refusing replacement");
  }
  if (GetFileAttributesW(executable.c_str()) == INVALID_FILE_ATTRIBUTES) throw std::runtime_error("Revisit executable missing");
  auto link = Link();
  Check(link->SetPath(executable.c_str()));
  Check(link->SetWorkingDirectory(executable.substr(0, executable.find_last_of(L"\\/")).c_str()));
  Check(link->SetDescription(L"Revisit - Save with intention. Return with purpose."));
  Check(link->SetIconLocation(executable.c_str(), 0));
  ComPtr<IPropertyStore> properties; Check(link.As(&properties));
  PROPVARIANT value{}; Check(InitPropVariantFromString(kNotificationAppId, &value));
  const HRESULT set = properties->SetValue(PKEY_AppUserModel_ID, value);
  PropVariantClear(&value); Check(set); Check(properties->Commit());
  ComPtr<IPersistFile> file; Check(link.As(&file));
  Check(file->Save(path.c_str(), TRUE));
}
void uninstall_notification_shortcut(const std::wstring& executable) {
  const auto path = notification_shortcut();
  if (GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES) return;
  if (!notification_configured(executable)) throw std::runtime_error("Shortcut ownership mismatch; refusing removal");
  if (!DeleteFileW(path.c_str())) throw std::runtime_error("Could not remove shortcut");
}

namespace {
constexpr wchar_t kIdentityKey[] = L"Software\\Classes\\AppUserModelId\\Revisit.Desktop";
std::wstring ReadIdentity(const wchar_t* name) {
  DWORD bytes = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, kIdentityKey, name, RRF_RT_REG_SZ, nullptr, nullptr, &bytes) != ERROR_SUCCESS || bytes > 65536) return {};
  std::vector<wchar_t> value(bytes / sizeof(wchar_t) + 1);
  if (RegGetValueW(HKEY_CURRENT_USER, kIdentityKey, name, RRF_RT_REG_SZ, nullptr, value.data(), &bytes) != ERROR_SUCCESS) return {};
  return value.data();
}
void WriteIdentity(HKEY key, const wchar_t* name, const std::wstring& value) {
  Check(HRESULT_FROM_WIN32(RegSetValueExW(key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()), static_cast<DWORD>((value.size()+1)*sizeof(wchar_t)))));
}
}
bool notification_identity_registered(const std::wstring& executable) {
  return SameFile(ReadIdentity(L"RevisitExecutable"), executable) &&
    ReadIdentity(L"DisplayName") == L"Revisit" && ReadIdentity(L"CustomActivator") == kToastActivatorText;
}
void register_notification_identity(const std::wstring& executable) {
  if (!notification_configured(executable)) throw std::runtime_error("Install the owned shortcut first");
  HKEY existing = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kIdentityKey, 0, KEY_READ, &existing) == ERROR_SUCCESS) {
    RegCloseKey(existing);
    if (!SameFile(ReadIdentity(L"RevisitExecutable"), executable)) throw std::runtime_error("Existing notification identity belongs to another installation; refusing replacement");
  }
  HKEY key = nullptr;
  Check(HRESULT_FROM_WIN32(RegCreateKeyExW(HKEY_CURRENT_USER, kIdentityKey, 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr)));
  try {
    WriteIdentity(key, L"RevisitExecutable", executable);
    WriteIdentity(key, L"DisplayName", L"Revisit");
    WriteIdentity(key, L"CustomActivator", kToastActivatorText);
  } catch (...) { RegCloseKey(key); throw; }
  RegCloseKey(key);
}
void unregister_notification_identity(const std::wstring& executable) {
  HKEY existing = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kIdentityKey, 0, KEY_READ, &existing) != ERROR_SUCCESS) return;
  RegCloseKey(existing);
  if (!SameFile(ReadIdentity(L"RevisitExecutable"), executable)) throw std::runtime_error("Identity ownership mismatch; refusing removal");
  Check(HRESULT_FROM_WIN32(RegDeleteKeyW(HKEY_CURRENT_USER, kIdentityKey)));
}
}
