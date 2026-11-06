#include "../../../windows/runner/notification_settings.h"
#include <iostream>
#include <stdexcept>

void check(bool value) {
  if (!value) throw std::runtime_error("notification settings assertion failed");
}
int main() {
  using winrt::Windows::UI::Notifications::NotificationSetting;
  using revisit::notification_submission_allowed;
  check(notification_submission_allowed([] { return NotificationSetting::Enabled; }));
  for (const auto setting : {NotificationSetting::DisabledForApplication,
       NotificationSetting::DisabledForUser, NotificationSetting::DisabledByGroupPolicy,
       NotificationSetting::DisabledByManifest}) {
    check(!notification_submission_allowed([=] { return setting; }));
  }
  bool propagated = false;
  try {
    notification_submission_allowed([]() -> NotificationSetting {
      throw winrt::hresult_error(E_ACCESSDENIED);
    });
  } catch (const winrt::hresult_error& error) {
    propagated = error.code() == E_ACCESSDENIED;
  }
  check(propagated);
  // A first genuine toast must reach Show even before Windows has initialized
  // the setting. No synthetic toast or system registration occurs in this test.
  check(notification_submission_allowed([]() -> NotificationSetting {
    throw winrt::hresult_error(HRESULT_FROM_WIN32(ERROR_NOT_FOUND));
  }));
  std::cout << "notification settings boundary passed\n";
}
