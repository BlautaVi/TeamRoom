#include "flutter_window.h"

#include <optional>
#include <shlwapi.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup method channel for WebView
  SetupMethodChannels();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SIZE: {
      // Resize WebView when window is resized
      RECT rect;
      GetClientRect(hwnd, &rect);
      WebViewHandler::GetInstance()->Resize(rect.right - rect.left, rect.bottom - rect.top);
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupMethodChannels() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.example.kurs/webview",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& method_call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto method_name = method_call.method_name();
        
        if (method_name.compare("loadHtml") == 0) {
          HandleLoadHtml(method_call, std::move(result));
        } else if (method_name.compare("dispose") == 0) {
          HandleDispose(std::move(result));
        } else if (method_name.compare("isAvailable") == 0) {
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  // Keep the channel alive
  method_channel_ = std::move(channel);
}

void FlutterWindow::HandleLoadHtml(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGS", "Arguments must be a map");
    return;
  }

  // Extract html content
  auto html_it = args->find(flutter::EncodableValue("html"));
  if (html_it == args->end()) {
    result->Error("MISSING_HTML", "HTML content is required");
    return;
  }

  auto* html_str = std::get_if<std::string>(&html_it->second);
  if (!html_str) {
    result->Error("INVALID_HTML", "HTML must be a string");
    return;
  }

  // Initialize WebView2 with window handle
  auto handler = WebViewHandler::GetInstance();
  handler->Initialize(GetHandle());
  
  // Load HTML in WebView2
  HRESULT hr = handler->LoadHtml(*html_str);
  
  if (SUCCEEDED(hr)) {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Error("WEBVIEW_ERROR", "Failed to load HTML in WebView2");
  }
}

void FlutterWindow::HandleDispose(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HRESULT hr = WebViewHandler::GetInstance()->Dispose();
  
  if (SUCCEEDED(hr)) {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Error("WEBVIEW_ERROR", "Failed to dispose WebView");
  }
}
