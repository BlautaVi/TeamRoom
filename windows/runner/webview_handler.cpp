#include "webview_handler.h"
#include <iostream>

WebViewHandler* WebViewHandler::instance_ = nullptr;

WebViewHandler* WebViewHandler::GetInstance() {
  if (!instance_) {
    instance_ = new WebViewHandler();
  }
  return instance_;
}

HRESULT WebViewHandler::Initialize(HWND parent_window) {
  parent_window_ = parent_window;
  
#ifdef WEBVIEW2_AVAILABLE
  if (!is_initialized_ && !is_initializing_) {
    // Create dedicated window for WebView
    webview_window_ = CreateWebViewWindow();
    if (!webview_window_) {
      std::cerr << "Failed to create WebView window" << std::endl;
      return E_FAIL;
    }
    return CreateWebViewEnvironment();
  }
#endif
  
  return S_OK;
}

#ifdef WEBVIEW2_AVAILABLE
HWND WebViewHandler::CreateWebViewWindow() {
  RECT parent_rect;
  GetClientRect(parent_window_, &parent_rect);
  
  HWND hwnd = CreateWindowEx(
    0,
    L"STATIC",
    L"WebView2",
    WS_CHILD | WS_VISIBLE,
    0, 0,
    parent_rect.right, parent_rect.bottom,
    parent_window_,
    nullptr,
    GetModuleHandle(nullptr),
    nullptr
  );
  
  if (hwnd) {
    std::cout << "Created WebView window HWND=" << hwnd << std::endl;
  }
  
  return hwnd;
}

HRESULT WebViewHandler::CreateWebViewEnvironment() {
  is_initializing_ = true;
  std::cout << "Creating WebView2 environment..." << std::endl;
  
  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
    nullptr, nullptr, nullptr,
    Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
      [this](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT {
        if (FAILED(result)) {
          std::cerr << "Failed to create WebView2 environment: 0x" << std::hex << result << std::endl;
          is_initializing_ = false;
          return result;
        }
        
        std::cout << "WebView2 environment created, creating controller..." << std::endl;
        webview_environment_ = environment;
        return CreateWebViewController();
      }
    ).Get()
  );
  
  if (FAILED(hr)) {
    std::cerr << "CreateCoreWebView2EnvironmentWithOptions failed: 0x" << std::hex << hr << std::endl;
    is_initializing_ = false;
  }
  
  return hr;
}

HRESULT WebViewHandler::CreateWebViewController() {
  if (!webview_environment_ || !webview_window_) {
    std::cerr << "CreateWebViewController: Missing environment or webview window" << std::endl;
    is_initializing_ = false;
    return E_FAIL;
  }
  
  std::cout << "Creating WebView2 controller for window HWND=" << webview_window_ << std::endl;
  
  HRESULT hr = webview_environment_->CreateCoreWebView2Controller(
    webview_window_,
    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
      [this](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
        if (FAILED(result)) {
          std::cerr << "Failed to create WebView2 controller: 0x" << std::hex << result << std::endl;
          is_initializing_ = false;
          return result;
        }
        
        std::cout << "WebView2 controller created" << std::endl;
        webview_controller_ = controller;
        webview_controller_->get_CoreWebView2(&webview_);
        
        // Enable DevTools for debugging
        ComPtr<ICoreWebView2Settings> settings;
        if (SUCCEEDED(webview_->get_Settings(&settings))) {
          settings->put_AreDevToolsEnabled(TRUE);
          settings->put_IsScriptEnabled(TRUE);
          settings->put_AreDefaultScriptDialogsEnabled(TRUE);
          settings->put_IsWebMessageEnabled(TRUE);
        }
        
        // Add permission request handler для камери та мікрофону
        webview_->add_PermissionRequested(
          Callback<ICoreWebView2PermissionRequestedEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
              COREWEBVIEW2_PERMISSION_KIND kind;
              args->get_PermissionKind(&kind);
              
              switch (kind) {
                case COREWEBVIEW2_PERMISSION_KIND_CAMERA:
                  std::cout << "Camera permission requested - GRANTING" << std::endl;
                  args->put_State(COREWEBVIEW2_PERMISSION_STATE_ALLOW);
                  break;
                case COREWEBVIEW2_PERMISSION_KIND_MICROPHONE:
                  std::cout << "Microphone permission requested - GRANTING" << std::endl;
                  args->put_State(COREWEBVIEW2_PERMISSION_STATE_ALLOW);
                  break;
                case COREWEBVIEW2_PERMISSION_KIND_CLIPBOARD_READ:
                  std::cout << "Clipboard read permission requested - GRANTING" << std::endl;
                  args->put_State(COREWEBVIEW2_PERMISSION_STATE_ALLOW);
                  break;
                default:
                  std::cout << "Other permission requested: " << kind << std::endl;
                  args->put_State(COREWEBVIEW2_PERMISSION_STATE_ALLOW);
                  break;
              }
              return S_OK;
            }
          ).Get(),
          nullptr
        );
        
        // Add console message handler for debugging
        webview_->add_WebMessageReceived(
          Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
              LPWSTR message;
              args->TryGetWebMessageAsString(&message);
              std::wcout << L"WebView console: " << message << std::endl;
              CoTaskMemFree(message);
              return S_OK;
            }
          ).Get(),
          nullptr
        );
        
        // Add navigation error handler
        webview_->add_NavigationCompleted(
          Callback<ICoreWebView2NavigationCompletedEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
              BOOL success;
              args->get_IsSuccess(&success);
              if (!success) {
                COREWEBVIEW2_WEB_ERROR_STATUS status;
                args->get_WebErrorStatus(&status);
                std::cerr << "Navigation failed with error: " << status << std::endl;
              } else {
                std::cout << "Navigation completed successfully" << std::endl;
              }
              return S_OK;
            }
          ).Get(),
          nullptr
        );
        
        // Intercept console.log
        webview_->ExecuteScript(
          LR"(
            const originalLog = console.log;
            const originalError = console.error;
            const originalWarn = console.warn;
            
            console.log = function(...args) {
              originalLog.apply(console, args);
              window.chrome.webview.postMessage('LOG: ' + args.join(' '));
            };
            
            console.error = function(...args) {
              originalError.apply(console, args);
              window.chrome.webview.postMessage('ERROR: ' + args.join(' '));
            };
            
            console.warn = function(...args) {
              originalWarn.apply(console, args);
              window.chrome.webview.postMessage('WARN: ' + args.join(' '));
            };
          )",
          nullptr
        );
        
        // Get window size and set bounds
        RECT bounds;
        GetClientRect(webview_window_, &bounds);
        std::cout << "Setting WebView bounds: " << bounds.right << "x" << bounds.bottom << std::endl;
        webview_controller_->put_Bounds(bounds);
        webview_controller_->put_IsVisible(TRUE);
        
        // Bring WebView window to front
        SetWindowPos(webview_window_, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        ShowWindow(webview_window_, SW_SHOW);
        UpdateWindow(webview_window_);
        
        is_initializing_ = false;
        is_initialized_ = true;
        
        // Load pending HTML if any
        if (!pending_html_.empty()) {
          std::cout << "Loading pending HTML (" << pending_html_.length() << " bytes)" << std::endl;
          
          // Properly convert UTF-8 to UTF-16
          int size_needed = MultiByteToWideChar(CP_UTF8, 0, pending_html_.c_str(), (int)pending_html_.length(), NULL, 0);
          std::wstring wide_html(size_needed, 0);
          MultiByteToWideChar(CP_UTF8, 0, pending_html_.c_str(), (int)pending_html_.length(), &wide_html[0], size_needed);
          
          webview_->NavigateToString(wide_html.c_str());
          pending_html_.clear();
        }
        
        std::cout << "WebView2 initialized successfully" << std::endl;
        return S_OK;
      }
    ).Get()
  );
  
  if (FAILED(hr)) {
    std::cerr << "CreateCoreWebView2Controller failed: 0x" << std::hex << hr << std::endl;
    is_initializing_ = false;
  }
  
  return hr;
}
#endif

HRESULT WebViewHandler::LoadHtml(const std::string& html_content) {
  std::cout << "LoadHtml called with " << html_content.length() << " bytes" << std::endl;
  std::cout << "WebView state - initialized: " << is_initialized_ << ", initializing: " << is_initializing_ << std::endl;
  
#ifdef WEBVIEW2_AVAILABLE
  if (is_initialized_ && webview_) {
    std::cout << "WebView is ready, navigating to HTML..." << std::endl;
    
    // Properly convert UTF-8 to UTF-16
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, html_content.c_str(), (int)html_content.length(), NULL, 0);
    std::wstring wide_html(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, html_content.c_str(), (int)html_content.length(), &wide_html[0], size_needed);
    
    HRESULT hr = webview_->NavigateToString(wide_html.c_str());
    if (SUCCEEDED(hr)) {
      std::cout << "NavigateToString succeeded" << std::endl;
    } else {
      std::cerr << "NavigateToString failed: 0x" << std::hex << hr << std::endl;
    }
    return hr;
  } else {
    std::cout << "WebView not ready yet, storing HTML for later" << std::endl;
    // Store HTML to load after initialization
    pending_html_ = html_content;
    if (!is_initializing_ && !is_initialized_) {
      std::cout << "Starting WebView initialization..." << std::endl;
      return Initialize(parent_window_);
    }
  }
#else
  std::cout << "WebView2 not available (WEBVIEW2_AVAILABLE not defined)" << std::endl;
#endif
  
  return S_OK;
}

HRESULT WebViewHandler::Dispose() {
#ifdef WEBVIEW2_AVAILABLE
  if (webview_controller_) {
    webview_controller_->Close();
    webview_controller_ = nullptr;
  }
  webview_ = nullptr;
  webview_environment_ = nullptr;
  
  if (webview_window_) {
    DestroyWindow(webview_window_);
    webview_window_ = nullptr;
  }
  
  is_initialized_ = false;
  is_initializing_ = false;
  pending_html_.clear();
#endif
  
  return S_OK;
}

void WebViewHandler::Resize(int width, int height) {
#ifdef WEBVIEW2_AVAILABLE
  if (webview_window_) {
    SetWindowPos(webview_window_, nullptr, 0, 0, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
  }
  if (webview_controller_) {
    RECT bounds = {0, 0, width, height};
    webview_controller_->put_Bounds(bounds);
  }
#endif
}
