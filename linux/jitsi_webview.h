#ifndef JITSI_WEBVIEW_H
#define JITSI_WEBVIEW_H

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

class JitsiWebView {
 public:
  static JitsiWebView* GetInstance();
  
  bool Initialize(GtkWidget* parent_widget);
  bool LoadHtml(const std::string& html_content);
  void Dispose();
  
 private:
  static JitsiWebView* instance_;
  
  GtkWidget* webview_widget_;
  WebKitWebView* webkit_view_;
  
  JitsiWebView();
  ~JitsiWebView();
};

#endif // JITSI_WEBVIEW_H
