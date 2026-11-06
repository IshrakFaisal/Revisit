#include "pipe_transport.h"
#include "protocol.h"
#include <charconv>
#include <iostream>
#include <string_view>

int main(int argc, char** argv) {
  int seconds = 120;
  if (argc != 1) {
    if (argc != 3 || std::string_view(argv[1]) != "--seconds") return 2;
    const std::string_view value(argv[2]);
    const auto parsed = std::from_chars(value.data(), value.data() + value.size(), seconds);
    if (parsed.ec != std::errc() || parsed.ptr != value.data() + value.size() || seconds < 1 || seconds > 3600) return 2;
  }
  HANDLE pipe = revisit::create_receiver_pipe();
  if (pipe == INVALID_HANDLE_VALUE) { std::cerr << "Cannot create private receiver pipe: " << GetLastError() << '\n'; return 1; }
  std::cout << "{\"status\":\"listening\",\"mode\":\"proof_only\"}" << std::endl;
  const auto deadline = GetTickCount64() + static_cast<ULONGLONG>(seconds) * 1000;
  revisit::ReplayGuard replay;
  while (GetTickCount64() < deadline) {
    if (!revisit::connect_receiver(pipe, 500)) continue;
    std::string input;
    revisit::Event event;
    std::string status = "invalid_event";
    if (revisit::receive_pipe_frame(pipe, input) && revisit::parse_event(input, revisit::now_ms(), event)) {
      status = replay.accept(event, revisit::now_ms()) ? "accepted" : "duplicate";
      if (status == "accepted") {
        // Only the authorized minimal event is emitted. No URL/page/title.
        std::cout << "{\"target\":\"" << event.target << "\",\"eventId\":\"" << event.event_id
          << "\",\"visitId\":\"" << event.visit_id << "\",\"occurredAt\":" << event.occurred_at
          << ",\"receivedAt\":" << revisit::now_ms() << "}" << std::endl;
      }
    }
    revisit::send_pipe_frame(pipe, "{\"status\":\"" + status + "\"}");
    // Client acknowledgement prevents DisconnectNamedPipe discarding unread reply.
    // The host closes its end after reading; a bounded read waits for that close.
    char unused = 0;
    revisit::transfer(pipe, &unused, 1, false, 1000);
    DisconnectNamedPipe(pipe);
  }
  CloseHandle(pipe);
  return 0;
}
