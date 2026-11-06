#include "../../../windows/runner/bounded_worker.h"
#include <future>
#include <iostream>
#include <stdexcept>

void check(bool condition) { if (!condition) throw std::runtime_error("worker assertion failed"); }
int main() {
  auto worker = std::make_unique<BoundedWorker>();
  std::promise<void> started, release, finished;
  auto gate = release.get_future().share();
  check(worker->TrySubmit([&] { started.set_value(); gate.wait(); finished.set_value(); }));
  check(started.get_future().wait_for(std::chrono::seconds(2)) == std::future_status::ready);
  // Native work is deliberately hung behind a gate: enqueue and destruction
  // must not wait for it, and a second operation must not queue for late replay.
  check(!worker->TrySubmit([] {}));
  worker.reset();
  release.set_value();
  check(finished.get_future().wait_for(std::chrono::seconds(2)) == std::future_status::ready);
  std::cout << "bounded worker passed\n";
}
