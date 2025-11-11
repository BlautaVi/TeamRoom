#pragma once

#include <string>
#include <windows.h>
#include <wrl.h>
#include <iostream>

#ifdef WEBVIEW2_AVAILABLE
#include "WebView2.h"
#endif

using namespace Microsoft::WRL;

class WebViewHandler {
 public:
  static WebViewHandler* GetInstance();

  HRESULT Initialize(HWND parent_window);
  HRESULT LoadHtml(const std::string& html_content);
  HRESULT Dispose();
  void Resize(int width, int height);

 private:
  static WebViewHandler* instance_;
  
  HWND parent_window_ = nullptr;
  HWND webview_window_ = nullptr;
  
#ifdef WEBVIEW2_AVAILABLE
  ComPtr<ICoreWebView2Environment> webview_environment_;
  ComPtr<ICoreWebView2Controller> webview_controller_;
  ComPtr<ICoreWebView2> webview_;
  bool is_initializing_ = false;
  bool is_initialized_ = false;
  std::string pending_html_;

  HRESULT CreateWebViewEnvironment();
  HRESULT CreateWebViewController();
  HWND CreateWebViewWindow();
#endif
};
