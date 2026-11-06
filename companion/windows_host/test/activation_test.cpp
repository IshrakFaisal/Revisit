#include "../../../windows/runner/toast_activation.h"
#include <iostream>
#include <stdexcept>
void check(bool ok) { if(!ok) throw std::runtime_error("activation assertion failed"); }
int main() {
  int64_t id=0;
  check(revisit::parse_activation(L"Revisit.Desktop",L"bookmark=42",id) && id==42);
  check(!revisit::parse_activation(L"Other",L"bookmark=42",id));
  check(!revisit::parse_activation(nullptr,L"bookmark=42",id));
  check(!revisit::parse_activation(L"Revisit.Desktop",nullptr,id));
  for(const auto value : {L"bookmark=0",L"bookmark=-1",L"bookmark=1&url=evil",L"bookmark=9223372036854775808",L"url=https://example.org"}) check(!revisit::parse_activation(L"Revisit.Desktop",value,id));
  check(revisit::parse_activation(L"Revisit.Desktop",L"bookmark=9223372036854775807",id));
  int64_t activated=0;
  auto callback=Microsoft::WRL::Make<revisit::ToastCallback>([&](int64_t value){activated=value;});
  check(callback->Activate(L"Revisit.Desktop",L"bookmark=7",nullptr,0)==S_OK && activated==7);
  check(callback->Activate(L"Other",L"bookmark=8",nullptr,0)==E_INVALIDARG && activated==7);
  std::cout << "activation boundary passed\n";
}
