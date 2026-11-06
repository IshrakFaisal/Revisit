#include "windows_reminders.h"
#include "bounded_worker.h"
#include "notification_identity.h"
#include "notification_settings.h"
#include "toast_activation.h"
#include "../../companion/windows_host/peer_identity.h"
#include "../../companion/windows_host/pipe_transport.h"
#include "../../companion/windows_host/protocol.h"
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.Notifications.h>
#include <chrono>
#include <deque>
#include <mutex>
#include <optional>
#include <atomic>
#include <future>
#include <flutter/method_result_functions.h>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
constexpr wchar_t kAppId[] = L"Revisit.Desktop";
int64_t Now() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
    std::chrono::system_clock::now().time_since_epoch()).count();
}
std::optional<int64_t> Integer(const Map& map, const char* key) {
  const auto item = map.find(Value(key));
  if (item == map.end()) return {};
  if (auto value = std::get_if<int64_t>(&item->second)) return *value;
  if (auto value = std::get_if<int32_t>(&item->second)) return *value;
  return {};
}
bool Registered() {
  // Validate the supported shortcut identity and its exact executable target.
  // This read-only check does not install anything or prove visible delivery.
  const auto executable = revisit::executable_path(GetCurrentProcessId());
  return revisit::notification_configured(executable) && revisit::notification_identity_registered(executable);
}
void EnsureApartment() {
  struct Apartment {
    Apartment() { winrt::init_apartment(winrt::apartment_type::multi_threaded); }
    ~Apartment() { winrt::uninit_apartment(); }
  };
  thread_local Apartment apartment;
}
}

struct WindowsReminders::State {
  struct Event {
    std::string method;
    Map data;
    std::shared_ptr<std::promise<std::string>> reply;
  };
  std::mutex mutex;
  HWND window;
  std::deque<Event> events;
  // Keep event subscriptions alive for recent in-process toast activation.
  // This collection is accessed only by the notification worker.
  std::deque<winrt::Windows::UI::Notifications::ToastNotification> toasts;
  BoundedWorker worker;
  DWORD activationCookie = 0;
  std::atomic<bool> receiverStarted{false}, receiverListening{false}, stopReceiver{false};
  explicit State(HWND hwnd) : window(hwnd) {}
  bool Emit(std::string method, Map data, std::shared_ptr<std::promise<std::string>> reply = {}) {
    std::lock_guard<std::mutex> lock(mutex);
    if (!window || events.size() >= 32) return false;
    events.push_back({std::move(method), std::move(data), std::move(reply)});
    PostMessageW(window, WindowsReminders::kMessage, 0, 0);
    return true;
  }
  void Receive() {
    HANDLE pipe = revisit::create_receiver_pipe(revisit::desktop_pipe_name());
    if (pipe == INVALID_HANDLE_VALUE) {
      Emit("receiverStatus", {{Value("status"), Value("unavailable")}});
      receiverStarted = false;
      if (stopReceiver) Emit("receiverStatus", {{Value("status"), Value("stopped")}});
      return;
    }
    receiverListening = true;
    Emit("receiverStatus", {{Value("status"), Value("listening")}});
    while (!stopReceiver) {
      if (!revisit::connect_receiver(pipe, 250)) continue;
      std::string input, status = "invalid_event";
      std::string response;
      revisit::Event event;
      revisit::Capture capture;
      if (revisit::trusted_desktop_client(pipe) && revisit::receive_pipe_frame(pipe, input)) {
        bool sent = false;
        if (revisit::parse_event(input, revisit::now_ms(), event)) {
          Map data{
            {Value("version"), Value(event.browser_prompt ? 2 : 1)}, {Value("target"), Value(event.target)},
            {Value("eventId"), Value(event.event_id)}, {Value("visitId"), Value(event.visit_id)},
            {Value("occurredAt"), Value(event.occurred_at)}};
          if (event.browser_prompt) {
            auto reply = std::make_shared<std::promise<std::string>>();
            auto result = reply->get_future();
            if (Emit("browserArrival", std::move(data), reply)) {
              if (result.wait_for(std::chrono::milliseconds(3500)) == std::future_status::ready) {
                response = result.get();
              }
            }
            status = "busy";
          } else if (event.needs_browser_update()) {
            status = "upgrade_required";
          } else {
            sent = Emit("contextArrival", std::move(data));
            status = sent ? "accepted" : "busy";
          }
        } else if (revisit::parse_capture(input, revisit::now_ms(), capture)) {
          sent = Emit("captureRequested", {
            {Value("version"), Value(1)}, {Value("kind"), Value(capture.kind)},
            {Value("url"), Value(capture.url)}, {Value("source"), Value(capture.source)},
            {Value("eventId"), Value(capture.event_id)}, {Value("occurredAt"), Value(capture.occurred_at)}});
          status = sent ? "accepted" : "busy";
        }
      }
      if (response.empty() || response.size() > revisit::kMaxMessage) {
        response = "{\"status\":\"" + status + "\"}";
      }
      revisit::send_pipe_frame(pipe, response);
      char unused = 0;
      revisit::transfer(pipe, &unused, 1, false, 1000);
      DisconnectNamedPipe(pipe);
    }
    CloseHandle(pipe);
    receiverListening = false;
    receiverStarted = false;
    Emit("receiverStatus", {{Value("status"), Value("stopped")}});
  }
};

WindowsReminders::WindowsReminders(HWND window, flutter::BinaryMessenger* messenger)
  : state_(std::make_shared<State>(window)),
    channel_(std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "revisit/windows", &flutter::StandardMethodCodec::GetInstance())) {
  auto factory = Microsoft::WRL::Make<revisit::ToastFactory>([weak = std::weak_ptr<State>(state_)](int64_t id) {
    if(auto live = weak.lock()) live->Emit("notificationActivated", {{Value("bookmarkId"),Value(id)}});
  });
  // Process-local registration only. No LocalServer32/autostart registration:
  // activation while closed is deliberately unsupported.
  CoRegisterClassObject(revisit::kToastActivator, factory.Get(), CLSCTX_LOCAL_SERVER,
    REGCLS_MULTIPLEUSE, &state_->activationCookie);
  channel_->SetMethodCallHandler([state = state_](const auto& call, auto result) {
    if (call.method_name() == "startReceiver") {
      bool expected = false;
      if (state->receiverStarted.compare_exchange_strong(expected, true)) {
        state->stopReceiver = false;
        std::thread([state] { state->Receive(); }).detach();
      } else {
        state->Emit("receiverStatus", {{Value("status"), Value(state->receiverListening ? "listening" : "starting")}});
      }
      result->Success();
      return;
    }
    if (call.method_name() == "stopReceiver") {
      state->stopReceiver = true;
      if (!state->receiverStarted) state->Emit("receiverStatus", {{Value("status"), Value("stopped")}});
      result->Success();
      return;
    }
    if (call.method_name() == "showWindow") {
      std::lock_guard<std::mutex> lock(state->mutex);
      if (state->window) {
        ShowWindow(state->window, SW_RESTORE);
        SetForegroundWindow(state->window);
      }
      result->Success();
      return;
    }
    if (call.method_name() == "notificationRegistration") {
      result->Success(Value(Registered() && state->activationCookie != 0));
      return;
    }
    if (call.method_name() != "submitNotification") {
      result->NotImplemented();
      return;
    }
    const auto* data = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
    if (!data) { result->Success(Value(false)); return; }
    const auto request = Integer(*data, "request");
    const auto id = Integer(*data, "bookmarkId");
    const auto deadline = Integer(*data, "expiresAt");
    const auto contextIt = data->find(Value("context"));
    const auto* context = contextIt == data->end() ? nullptr : std::get_if<std::string>(&contextIt->second);
    if (data->size() != 4 || !request || *request <= 0 || !id || *id <= 0 ||
        !deadline || *deadline <= Now() || *deadline > Now() + 300000 ||
        !context || (*context != "x" && *context != "github" && *context != "facebook")) {
      result->Success(Value(false)); return;
    }
    const auto accepted = state->worker.TrySubmit(
      [weak = std::weak_ptr<State>(state), request = *request, id = *id,
       deadline = *deadline] {
        const auto shared = weak.lock();
        if (!shared) return;
        std::string outcome = "failed";
        bool showStarted = false;
        try {
          EnsureApartment();
          if (Registered() && shared->activationCookie != 0 && Now() < deadline) {
            using namespace winrt::Windows::UI::Notifications;
            const auto notifier = ToastNotificationManager::CreateToastNotifier(kAppId);
            if (revisit::notification_submission_allowed([&] { return notifier.Setting(); })) {
              winrt::Windows::Data::Xml::Dom::XmlDocument xml;
              // Deliberately omit the saved title, intention and URL from all
              // toast surfaces, including the lock screen. ID is activation-only.
              xml.LoadXml(L"<toast launch='bookmark=" + std::to_wstring(id) + L"'><visual><binding template='ToastGeneric'>"
                L"<text>Revisit</text><text>A saved item is ready to revisit."
                L" Open Revisit to see your intention.</text></binding></visual></toast>");
              ToastNotification toast(xml);
              toast.Tag(winrt::to_hstring(id));
              toast.ExpirationTime(winrt::clock::from_sys(
                std::chrono::system_clock::time_point(std::chrono::milliseconds(deadline))));
              // No late submission from queue delay, initialization or XML work.
              if (Now() < deadline) {
                showStarted = true;
                notifier.Show(toast);
                shared->toasts.push_back(toast);
                if (shared->toasts.size() > 32) shared->toasts.pop_front();
                outcome = "submitted";
              }
            }
          }
        } catch (...) {
          outcome = showStarted ? "unknown" : "failed";
        }
        shared->Emit("notificationResult", {{Value("request"), Value(request)}, {Value("outcome"), Value(outcome)}});
      });
    result->Success(Value(accepted));
  });
}

WindowsReminders::~WindowsReminders() {
  if(state_->activationCookie) CoRevokeClassObject(state_->activationCookie);
  state_->stopReceiver = true;
  channel_->SetMethodCallHandler(nullptr);
  std::lock_guard<std::mutex> lock(state_->mutex);
  state_->window = nullptr;
  state_->events.clear();
}

void WindowsReminders::Drain() {
  std::deque<State::Event> events;
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    events.swap(state_->events);
  }
  for (auto& event : events) {
    std::unique_ptr<flutter::MethodResult<Value>> result;
    if (event.reply) {
      result = std::make_unique<flutter::MethodResultFunctions<Value>>(
        [reply = event.reply](const Value* value) {
          const auto* json = value ? std::get_if<std::string>(value) : nullptr;
          reply->set_value(json ? *json : "");
        },
        [reply = event.reply](const std::string&, const std::string&, const Value*) {
          reply->set_value("");
        },
        [reply = event.reply]() { reply->set_value(""); });
    }
    channel_->InvokeMethod(event.method, std::make_unique<Value>(event.data), std::move(result));
  }
}
