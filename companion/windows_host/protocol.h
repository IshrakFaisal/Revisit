#pragma once
#include <cstdint>
#include <istream>
#include <ostream>
#include <string>
#include <unordered_map>

namespace revisit {
constexpr std::uint32_t kMaxMessage = 4096;
constexpr const char* kOrigin = "chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/";
struct Event {
  std::string target, event_id, visit_id;
  std::int64_t occurred_at = 0;
  bool browser_prompt = false;
  // Old social arrivals must not consume the cooldown for an in-page reminder.
  bool needs_browser_update() const { return !browser_prompt && target != "github"; }
};
struct Capture {
  std::string kind, url, source, event_id;
  std::int64_t occurred_at = 0;
};
struct BrowserQuery {
  std::string kind, target, cursor, event_id;
  std::int64_t occurred_at = 0;
};
bool parse_browser_query(const std::string& json, std::int64_t now, BrowserQuery& result);
std::int64_t now_ms();
bool parse_event(const std::string& json, std::int64_t now, Event& result);
bool parse_capture(const std::string& json, std::int64_t now, Capture& result);
bool read_frame(std::istream& input, std::string& payload);
bool write_frame(std::ostream& output, const std::string& payload);
std::string frame(const std::string& payload);
// Bounded process-local deduplication for the proof, not application persistence.
class ReplayGuard {
 public:
  bool accept(const Event& event, std::int64_t now);
 private:
  std::unordered_map<std::string, std::int64_t> entries_;
};
}  // namespace revisit
