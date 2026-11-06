#pragma once
#include <string>
#include <windows.h>
namespace revisit {
inline constexpr wchar_t kNotificationAppId[] = L"Revisit.Desktop";
inline constexpr GUID kToastActivator = {0xf4164211,0x5c68,0x4ddc,{0xa1,0x1b,0xd9,0x04,0x25,0x4b,0x10,0x90}};
inline constexpr wchar_t kToastActivatorText[] = L"{F4164211-5C68-4DDC-A11B-D904254B1090}";
bool notification_identity_registered(const std::wstring& executable);
void register_notification_identity(const std::wstring& executable);
void unregister_notification_identity(const std::wstring& executable);
std::wstring notification_shortcut();
bool notification_configured(const std::wstring& executable);
void install_notification_shortcut(const std::wstring& executable);
void uninstall_notification_shortcut(const std::wstring& executable);
}
