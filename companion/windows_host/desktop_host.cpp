#include "peer_identity.h"
#include "pipe_transport.h"
#include "protocol.h"
#include <fcntl.h>
#include <io.h>
#include <iostream>

int main(int argc, char** argv) {
  if (argc < 2 || std::string(argv[1]) != revisit::kOrigin) return 2;
  if (!revisit::trusted_chrome_stdio()) return 4;
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
  std::string input, status = "invalid_event";
  revisit::Event event;
  revisit::Capture capture;
  revisit::BrowserQuery query;
  if (revisit::read_frame(std::cin, input) &&
      (revisit::parse_event(input, revisit::now_ms(), event) ||
       revisit::parse_capture(input, revisit::now_ms(), capture) ||
       revisit::parse_browser_query(input, revisit::now_ms(), query))) {
    const auto name = revisit::desktop_pipe_name();
    HANDLE pipe = name.empty() ? INVALID_HANDLE_VALUE : CreateFileW(name.c_str(), GENERIC_READ | GENERIC_WRITE,
      0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
    status = "receiver_unavailable";
    if (pipe != INVALID_HANDLE_VALUE) {
      std::string reply;
      const bool trusted = revisit::trusted_desktop_server(pipe);
      if (trusted && !capture.kind.empty()) {
        // The browser launched this host after an explicit Save/Yes click.
        // Transfer foreground permission only to the authenticated receiver;
        // automatic arrivals never grant it. Windows may still deny focus.
        ULONG receiver = 0;
        if (GetNamedPipeServerProcessId(pipe, &receiver) && receiver != 0) {
          AllowSetForegroundWindow(receiver);
        }
      }
      if (trusted && revisit::send_pipe_frame(pipe, input) &&
          revisit::receive_pipe_frame(pipe, reply, event.browser_prompt || !query.kind.empty() ? 4500 : 2000)) {
        if (reply == "{\"status\":\"accepted\"}" || reply == "{\"status\":\"invalid_event\"}" || reply == "{\"status\":\"busy\"}" ||
            (event.needs_browser_update() && reply == "{\"status\":\"upgrade_required\"}") ||
            (event.browser_prompt && (reply == "{\"status\":\"no_reminder\"}" || reply.rfind("{\"status\":\"reminder\",", 0) == 0)) ||
            (!query.kind.empty() && (reply.rfind("{\"status\":\"bookmarks\",", 0) == 0 || reply.rfind("{\"status\":\"open\",", 0) == 0 ||
              reply == "{\"status\":\"unavailable\"}" || reply == "{\"status\":\"too_large\"}"))) {
          CloseHandle(pipe);
          return revisit::write_frame(std::cout, reply) ? 0 : 3;
        }
      }
      CloseHandle(pipe);
    }
  }
  return revisit::write_frame(std::cout, "{\"status\":\"" + status + "\"}") ? 0 : 3;
}
