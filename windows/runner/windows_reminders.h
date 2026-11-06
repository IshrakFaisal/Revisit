#pragma once
#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

class WindowsReminders {
 public:
  static constexpr UINT kMessage = WM_APP + 41;
  WindowsReminders(HWND window, flutter::BinaryMessenger* messenger);
  ~WindowsReminders();
  void Drain();
 private:
  struct State;
  std::shared_ptr<State> state_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
