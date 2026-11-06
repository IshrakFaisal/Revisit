#pragma once
#include <windows.h>
#include <winrt/Windows.UI.Notifications.h>

namespace revisit {
template <typename Query>
bool notification_submission_allowed(Query query) {
  try {
    return query() == winrt::Windows::UI::Notifications::NotificationSetting::Enabled;
  } catch (const winrt::hresult_error& error) {
    // Unpackaged apps can have no setting until their first Show call. Let
    // that real request reach Windows, which still enforces OS preferences.
    // Do not send a synthetic initialization toast or mask other errors.
    if (error.code() == HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) return true;
    throw;
  }
}
}
