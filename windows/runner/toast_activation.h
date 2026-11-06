#pragma once
#include <windows.h>
#include <NotificationActivationCallback.h>
#include <wrl/client.h>
#include <wrl/implements.h>
#include <functional>
#include <string>
#include <limits>
#include "notification_identity.h"

namespace revisit {
inline bool parse_activation(const wchar_t* appId, const wchar_t* arguments, int64_t& id) {
  if (!appId || std::wstring(appId) != kNotificationAppId || !arguments) return false;
  const std::wstring value(arguments);
  const std::wstring prefix = L"bookmark=";
  if (value.size() <= prefix.size() || value.size() > prefix.size()+19 || value.compare(0,prefix.size(),prefix)!=0) return false;
  id = 0;
  for (size_t i=prefix.size();i<value.size();++i) {
    if (value[i]<L'0' || value[i]>L'9') return false;
    const int digit=value[i]-L'0';
    if(id>(std::numeric_limits<int64_t>::max()-digit)/10) return false;
    id=id*10+digit;
  }
  return id>0;
}
class ToastCallback final : public Microsoft::WRL::RuntimeClass<Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, INotificationActivationCallback> {
 public:
  explicit ToastCallback(std::function<void(int64_t)> callback): callback_(std::move(callback)) {}
  HRESULT STDMETHODCALLTYPE Activate(LPCWSTR appId, LPCWSTR arguments, const NOTIFICATION_USER_INPUT_DATA*, ULONG) override {
    int64_t id=0;
    if(!parse_activation(appId, arguments, id)) return E_INVALIDARG;
    callback_(id);
    return S_OK;
  }
 private:
  std::function<void(int64_t)> callback_;
};
class ToastFactory final : public Microsoft::WRL::RuntimeClass<Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, IClassFactory> {
 public:
  explicit ToastFactory(std::function<void(int64_t)> callback): callback_(std::move(callback)) {}
  HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** object) override {
    if(!object) return E_POINTER;
    *object=nullptr;
    if(outer) return CLASS_E_NOAGGREGATION;
    return Microsoft::WRL::Make<ToastCallback>(callback_).CopyTo(iid, object);
  }
  HRESULT STDMETHODCALLTYPE LockServer(BOOL) override {return S_OK;}
 private:
  std::function<void(int64_t)> callback_;
};
}
