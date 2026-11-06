#include "protocol.h"
#include <cstdlib>
#include <iostream>
#include <sstream>

void require(bool condition, const char* message) {
  if (!condition) { std::cerr << message << '\n'; std::exit(1); }
}
int main() {
  const std::int64_t now = 1700000000000;
  const std::string valid = R"({"version":1,"target":"github","eventId":"01234567-89ab-cdef-0123-456789abcdef","visitId":"11234567-89ab-cdef-0123-456789abcdef","occurredAt":1700000000000})";
  revisit::Event event;
  auto facebook = valid;
  facebook.replace(facebook.find("github"), 6, "facebook");
  require(revisit::parse_event(facebook, now, event), "Facebook arrival rejected");
  require(event.needs_browser_update(), "old Facebook arrival can spend the reminder cooldown");
  auto oldX = valid;
  oldX.replace(oldX.find("github"), 6, "x");
  require(revisit::parse_event(oldX, now, event) && event.needs_browser_update(), "old X arrival can spend the reminder cooldown");
  auto browser = facebook;
  browser.replace(browser.find("\"version\":1"), 11, "\"version\":2");
  require(revisit::parse_event(browser, now, event) && event.browser_prompt && !event.needs_browser_update(), "in-page arrival rejected");
  auto unsupportedBrowser = valid;
  unsupportedBrowser.replace(unsupportedBrowser.find("\"version\":1"), 11, "\"version\":2");
  require(!revisit::parse_event(unsupportedBrowser, now, event), "unsupported in-page context accepted");
  revisit::Capture capture;
  const std::string captured = R"({"version":1,"kind":"capture","url":"https://www.facebook.com/example/posts/123","source":"facebook","eventId":"01234567-89ab-cdef-0123-456789abcdef","occurredAt":1700000000000})";
  require(revisit::parse_capture(captured, now, capture), "explicit Facebook capture rejected");
  auto siteSave = captured;
  siteSave.replace(siteSave.find("\"capture\""), 9, "\"siteSave\"");
  require(revisit::parse_capture(siteSave, now, capture) && capture.kind == "siteSave", "site save capture rejected");
  require(capture.source == "facebook" && capture.url == "https://www.facebook.com/example/posts/123", "capture fields changed");
  require(revisit::parse_capture(captured, now + 30000, capture), "capture freshness boundary rejected");
  require(!revisit::parse_capture(captured, now + 30001, capture), "stale capture accepted");
  require(!revisit::parse_capture(captured, now - 5001, capture), "future capture accepted");
  for (const auto& item : {
      std::pair<std::string, std::string>{"https://x.com/user/status/1", "x"},
      {"https://mobile.twitter.com/user/status/1", "x"},
      {"https://github.com/owner/repo", "github"},
      {"https://gist.github.com/owner/id", "github"},
      {"https://m.facebook.com/story.php?story_fbid=1&id=2", "facebook"}}) {
    auto value = captured;
    value.replace(value.find("https://www.facebook.com/example/posts/123"), 42, item.first);
    value.replace(value.find("\"source\":\"facebook\""), 19, "\"source\":\"" + item.second + "\"");
    require(revisit::parse_capture(value, now, capture), "supported source capture rejected");
  }
  for (const auto& url : {"javascript:alert(1)", "http://www.facebook.com/post/1",
      "https://facebook.com.evil.test/", "https://evil@facebook.com/", "https://facebook.com:444/",
      "https://github.com/", "https://facebook.com/has space", "https://facebook.com/has\\escape",
      "https://facebook.com/%zz", "https://facebook.com/%2", "https://facebook.com/<bad>"}) {
    auto value = captured;
    value.replace(value.find("https://www.facebook.com/example/posts/123"), 42, url);
    require(!revisit::parse_capture(value, now, capture), "unsafe or source-mismatched capture accepted");
  }
  for (const auto& invalid : {captured + "x", captured.substr(0, captured.size()-1), std::string(4097, ' ')}) {
    require(!revisit::parse_capture(invalid, now, capture), "malformed capture accepted");
  }
  auto captureExtra = captured;
  captureExtra.insert(captureExtra.size()-1, ",\"trusted\":true");
  require(!revisit::parse_capture(captureExtra, now, capture), "capture extra field accepted");
  auto captureDuplicate = captured;
  captureDuplicate.replace(captureDuplicate.find("kind"), 4, "source");
  require(!revisit::parse_capture(captureDuplicate, now, capture), "capture duplicate key accepted");
  auto longCapture = captured;
  longCapture.replace(longCapture.find("https://www.facebook.com/example/posts/123"), 42,
    "https://www.facebook.com/" + std::string(3072, 'a'));
  require(!revisit::parse_capture(longCapture, now, capture), "oversized capture URL accepted");
  require(revisit::parse_event(valid, now, event), "valid event rejected");
  require(!event.needs_browser_update(), "GitHub Windows toast no longer supported");
  require(event.target == "github", "incorrect context");
  require(revisit::parse_event(valid, now + 30000, event), "freshness boundary rejected");
  require(!revisit::parse_event(valid, now + 30001, event), "stale event accepted");
  require(revisit::parse_event(valid, now - 5000, event), "future boundary rejected");
  require(!revisit::parse_event(valid, now - 5001, event), "future event accepted");
  for (const auto& invalid : {std::string(), std::string("{}"), valid + " trailing", valid.substr(0, valid.size() - 1), std::string(4097, ' ')}) require(!revisit::parse_event(invalid, now, event), "malformed input accepted");
  for (const auto& replacement : {std::string("unknown"), std::string("github.com"), std::string("gith\\ub")}) {
    auto invalid = valid;
    invalid.replace(invalid.find("github"), 6, replacement);
    require(!revisit::parse_event(invalid, now, event), "invalid target accepted");
  }
  auto extra = valid;
  extra.insert(extra.size() - 1, ",\"source\":\"trusted\"");
  require(!revisit::parse_event(extra, now, event), "unknown field accepted");
  auto duplicate = valid;
  duplicate.replace(duplicate.find("visitId"), 7, "eventId");
  require(!revisit::parse_event(duplicate, now, event), "duplicate key accepted");
  for (const auto number : {"1e12", "-1", "01", "9223372036854775808", "1700000000000.0"}) {
    auto invalid = valid;
    invalid.replace(invalid.find("1700000000000"), 13, number);
    require(!revisit::parse_event(invalid, now, event), "invalid timestamp accepted");
  }
  const auto framed = revisit::frame(valid);
  std::istringstream input(framed);
  std::string decoded;
  require(revisit::read_frame(input, decoded) && decoded == valid, "frame round trip failed");
  for (std::size_t i = 0; i < framed.size(); ++i) {
    std::istringstream truncated(framed.substr(0, i));
    require(!revisit::read_frame(truncated, decoded), "truncated frame accepted");
  }
  std::istringstream huge(std::string("\xff\xff\xff\x7f", 4));
  require(!revisit::read_frame(huge, decoded), "oversized frame accepted");
  require(revisit::frame(std::string(4097, 'x')).empty(), "oversized output accepted");
  revisit::ReplayGuard replay;
  require(replay.accept(event, now), "first event rejected");
  for (int i = 0; i < 100; ++i) require(!replay.accept(event, now), "replayed event accepted");
  event.event_id[0] = 'a';
  require(!replay.accept(event, now), "replayed visit accepted");
  event.visit_id[0] = 'b';
  require(replay.accept(event, now), "new visit rejected");
  std::cout << "Protocol validation, framing and replay checks passed.\n";
}
