#include "notification_identity.h"
#include <windows.h>
#include <iostream>
#include <vector>
#include <winrt/Windows.UI.Notifications.h>
int wmain(int argc, wchar_t** argv) {
  if (argc != 2) { std::cerr << "Use --check, --install, --uninstall, --register-identity or --unregister-identity. Setup is per user.\n"; return 2; }
  const std::wstring action(argv[1]);
  if(action != L"--check" && action != L"--install" && action != L"--uninstall" && action != L"--register-identity" && action != L"--unregister-identity") return 2;
  const HRESULT apartment = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if(FAILED(apartment)) return 3;
  int result = 0;
  try {
    std::vector<wchar_t> own(32768);
    const DWORD length = GetModuleFileNameW(nullptr, own.data(), static_cast<DWORD>(own.size()));
    if(!length || length >= own.size()) throw std::runtime_error("Executable path unavailable");
    const std::wstring path(own.data(), length);
    const auto app = path.substr(0, path.find_last_of(L"\\/") + 1) + L"revisit.exe";
    if(action == L"--install") revisit::install_notification_shortcut(app);
    if(action == L"--uninstall") revisit::uninstall_notification_shortcut(app);
    if(action == L"--register-identity") revisit::register_notification_identity(app);
    if(action == L"--unregister-identity") revisit::unregister_notification_identity(app);
    const bool configured = revisit::notification_configured(app);
    std::wcout << L"Shortcut: " << revisit::notification_shortcut() << L"\nTarget: " << app << L"\n";
    std::cout << (configured ? "Shortcut configured; visible notification delivery still requires verification.\n" : "Shortcut not configured for this bundle.\n");
    std::cout << "Registered Windows identity: " << revisit::notification_identity_registered(app) << "\n";
    if(configured && action == L"--check") {
      try {
        const auto notifier = winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier(revisit::kNotificationAppId);
        const auto setting = notifier.Setting();
        std::cout << "Windows notification setting: " << static_cast<int>(setting) << " (0=enabled, 1=app disabled, 2=user disabled, 3=policy disabled, 4=manifest disabled)\n";
      } catch(const winrt::hresult_error& error) {
        if(error.code() == HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) {
          std::cout << "Windows setting not initialized; a first genuine notification is required to verify delivery. No test toast was sent.\n";
        } else {
          std::wcerr << L"Notification service error: " << error.message().c_str() << L"\n";
          result = 4;
        }
      }
    }
    if(action == L"--check" && !revisit::notification_identity_registered(app)) result = 1;
    if(action != L"--uninstall" && !configured) result = 1;
  } catch(const std::exception& e) { std::cerr << e.what() << '\n'; result = 3; }
  CoUninitialize();
  return result;
}
