#include "protocol.h"
#include <charconv>
#include <chrono>
#include <limits>
#include <set>

namespace revisit {
namespace {
// Deliberately accepts only this protocol's ASCII keys/enum/UUIDs and integer
// values. Escaped strings, extra keys, floats, nested objects and duplicate keys
// are rejected rather than interpreted by a permissive general JSON parser.
class Parser {
 public:
  explicit Parser(const std::string& value) : value_(value) {}
  void space() { while (pos_ < value_.size() && (value_[pos_] == ' ' || value_[pos_] == '\t' || value_[pos_] == '\r' || value_[pos_] == '\n')) ++pos_; }
  bool take(char c) { space(); if (pos_ == value_.size() || value_[pos_] != c) return false; ++pos_; return true; }
  bool end() { space(); return pos_ == value_.size(); }
  bool text(std::string& output) {
    if (!take('"')) return false;
    const auto start = pos_;
    while (pos_ < value_.size() && value_[pos_] != '"') {
      const unsigned char c = static_cast<unsigned char>(value_[pos_++]);
      if (c < 32 || c > 126 || c == '\\') return false;
    }
    if (pos_ == value_.size()) return false;
    output = value_.substr(start, pos_ - start);
    ++pos_;
    return true;
  }
  bool number(std::int64_t& output) {
    space();
    const auto start = pos_;
    while (pos_ < value_.size() && value_[pos_] >= '0' && value_[pos_] <= '9') ++pos_;
    if (start == pos_ || (pos_ - start > 1 && value_[start] == '0')) return false;
    return std::from_chars(value_.data() + start, value_.data() + pos_, output).ec == std::errc();
  }
 private:
  const std::string& value_;
  std::size_t pos_ = 0;
};
bool uuid(const std::string& value) {
  if (value.size() != 36) return false;
  for (std::size_t i = 0; i < value.size(); ++i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) { if (value[i] != '-') return false; }
    else if (!((value[i] >= '0' && value[i] <= '9') || (value[i] >= 'a' && value[i] <= 'f'))) return false;
  }
  return true;
}
}  // namespace

std::int64_t now_ms() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}
bool parse_capture(const std::string& json, std::int64_t now, Capture& result) {
  if (json.empty() || json.size() > kMaxMessage || now < 30000 ||
      now > std::numeric_limits<std::int64_t>::max() - 5000) return false;
  Parser parser(json);
  Capture capture;
  std::set<std::string> keys;
  std::int64_t version = 0;
  if (!parser.take('{')) return false;
  for (int i = 0; i < 6; ++i) {
    if (i && !parser.take(',')) return false;
    std::string key;
    if (!parser.text(key) || !keys.insert(key).second || !parser.take(':')) return false;
    if (key == "version") { if (!parser.number(version)) return false; }
    else if (key == "kind") { if (!parser.text(capture.kind)) return false; }
    else if (key == "url") { if (!parser.text(capture.url)) return false; }
    else if (key == "source") { if (!parser.text(capture.source)) return false; }
    else if (key == "eventId") { if (!parser.text(capture.event_id)) return false; }
    else if (key == "occurredAt") { if (!parser.number(capture.occurred_at)) return false; }
    else return false;
  }
  if (!parser.take('}') || !parser.end() || version != 1 ||
      (capture.kind != "capture" && capture.kind != "siteSave") ||
      !uuid(capture.event_id) || capture.occurred_at < now - 30000 ||
      capture.occurred_at > now + 5000 || capture.url.size() > 3072 ||
      capture.url.compare(0, 8, "https://") != 0) return false;
  const auto hostEnd = capture.url.find_first_of("/?#", 8);
  const auto host = capture.url.substr(8, hostEnd == std::string::npos ? hostEnd : hostEnd - 8);
  std::string source;
  if (host == "x.com" || host == "www.x.com" || host == "twitter.com" ||
      host == "www.twitter.com" || host == "mobile.twitter.com") source = "x";
  if (host == "facebook.com" || host == "www.facebook.com" ||
      host == "m.facebook.com" || host == "mbasic.facebook.com") source = "facebook";
  if (host == "github.com" || host == "www.github.com" || host == "gist.github.com") source = "github";
  if (source.empty() || source != capture.source ||
      capture.url.find_first_of(" <>\"{}|^`") != std::string::npos) return false;
  if (capture.kind == "siteSave" && source != "x" && source != "facebook") return false;
  const auto hex = [](char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
  };
  for (std::size_t i = 0; i < capture.url.size(); ++i) {
    if (capture.url[i] == '%' &&
        (i + 2 >= capture.url.size() || !hex(capture.url[i + 1]) || !hex(capture.url[i + 2]))) return false;
  }
  result = capture;
  return true;
}
bool parse_event(const std::string& json, std::int64_t now, Event& result) {
  if (json.empty() || json.size() > kMaxMessage) return false;
  Parser parser(json);
  Event event;
  std::set<std::string> keys;
  std::int64_t version = 0;
  if (!parser.take('{')) return false;
  for (int i = 0; i < 5; ++i) {
    if (i && !parser.take(',')) return false;
    std::string key;
    if (!parser.text(key) || !keys.insert(key).second || !parser.take(':')) return false;
    if (key == "version") { if (!parser.number(version)) return false; }
    else if (key == "occurredAt") { if (!parser.number(event.occurred_at)) return false; }
    else if (key == "target") { if (!parser.text(event.target)) return false; }
    else if (key == "eventId") { if (!parser.text(event.event_id)) return false; }
    else if (key == "visitId") { if (!parser.text(event.visit_id)) return false; }
    else return false;
  }
  if (!parser.take('}') || !parser.end() || (version != 1 && version != 2) || !uuid(event.event_id) || !uuid(event.visit_id)) return false;
  if (event.target != "x" && event.target != "github" && event.target != "facebook") return false;
  if (version == 2 && event.target == "github") return false;
  event.browser_prompt = version == 2;
  if (now < 30000 || now > std::numeric_limits<std::int64_t>::max() - 5000) return false;
  if (event.occurred_at < now - 30000 || event.occurred_at > now + 5000) return false;
  result = event;
  return true;
}
std::string frame(const std::string& payload) {
  if (payload.empty() || payload.size() > kMaxMessage) return {};
  std::string data(4, '\0');
  const auto length = static_cast<std::uint32_t>(payload.size());
  for (unsigned int i = 0; i < 4; ++i) data[i] = static_cast<char>((length >> (i * 8)) & 0xff);
  return data + payload;
}
bool read_frame(std::istream& input, std::string& payload) {
  unsigned char header[4];
  if (!input.read(reinterpret_cast<char*>(header), 4)) return false;
  std::uint32_t length = 0;
  for (unsigned int i = 0; i < 4; ++i) length |= static_cast<std::uint32_t>(header[i]) << (i * 8);
  if (!length || length > kMaxMessage) return false;
  payload.resize(length);
  return static_cast<bool>(input.read(payload.data(), length));
}
bool write_frame(std::ostream& output, const std::string& payload) {
  const auto data = frame(payload);
  if (data.empty()) return false;
  output.write(data.data(), static_cast<std::streamsize>(data.size()));
  output.flush();
  return static_cast<bool>(output);
}
bool ReplayGuard::accept(const Event& event, std::int64_t now) {
  for (auto it = entries_.begin(); it != entries_.end();) {
    if (it->second < now - 35000) it = entries_.erase(it); else ++it;
  }
  const auto event_key = "e:" + event.event_id;
  const auto visit_key = "v:" + event.visit_id;
  if (entries_.count(event_key) || entries_.count(visit_key) || entries_.size() >= 2048) return false;
  entries_[event_key] = now;
  entries_[visit_key] = now;
  return true;
}
}  // namespace revisit
