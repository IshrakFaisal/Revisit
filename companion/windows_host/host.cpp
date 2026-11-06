#include "pipe_transport.h"
#include "protocol.h"
#include <fcntl.h>
#include <io.h>
#include <iostream>

int main(int argc, char** argv) {
  // Chrome supplies the extension origin as argv[1]. No wildcard origins.
  if (argc < 2 || std::string(argv[1]) != revisit::kOrigin) return 2;
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
  std::string input;
  revisit::Event event;
  std::string status = "invalid_event";
  if (revisit::read_frame(std::cin, input) && revisit::parse_event(input, revisit::now_ms(), event)) {
    const auto name = revisit::pipe_name();
    HANDLE pipe = name.empty() ? INVALID_HANDLE_VALUE : CreateFileW(name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
    status = "receiver_unavailable";
    if (pipe != INVALID_HANDLE_VALUE) {
      std::string reply;
      if (revisit::send_pipe_frame(pipe, input) && revisit::receive_pipe_frame(pipe, reply)) {
        if (reply == "{\"status\":\"accepted\"}" || reply == "{\"status\":\"duplicate\"}" || reply == "{\"status\":\"invalid_event\"}") {
          CloseHandle(pipe);
          return revisit::write_frame(std::cout, reply) ? 0 : 3;
        }
      }
      CloseHandle(pipe);
    }
  }
  return revisit::write_frame(std::cout, "{\"status\":\"" + status + "\"}") ? 0 : 3;
}
