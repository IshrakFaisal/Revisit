#pragma once
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>

// One in-flight operation, no queued replay. Destruction never waits for a
// potentially blocked OS call. The worker owns its state until it exits.
class BoundedWorker {
 public:
  BoundedWorker() : state_(std::make_shared<State>()) {
    std::thread([state = state_] {
      for (;;) {
        std::function<void()> job;
        {
          std::unique_lock<std::mutex> lock(state->mutex);
          state->ready.wait(lock, [&] { return state->stopped || state->job; });
          if (state->stopped) return;
          job = std::move(state->job);
        }
        try { job(); } catch (...) { /* A job must report its own outcome. */ }
        std::lock_guard<std::mutex> lock(state->mutex);
        state->busy = false;
      }
    }).detach();
  }
  ~BoundedWorker() {
    {
      std::lock_guard<std::mutex> lock(state_->mutex);
      state_->stopped = true;
      state_->job = {};
    }
    state_->ready.notify_one();
  }
  bool TrySubmit(std::function<void()> job) {
    std::unique_lock<std::mutex> lock(state_->mutex, std::try_to_lock);
    if (!lock || state_->stopped || state_->busy) return false;
    state_->busy = true;
    state_->job = std::move(job);
    state_->ready.notify_one();
    return true;
  }
 private:
  struct State {
    std::mutex mutex;
    std::condition_variable ready;
    bool busy = false, stopped = false;
    std::function<void()> job;
  };
  std::shared_ptr<State> state_;
};
