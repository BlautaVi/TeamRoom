# 💬 TeamRoom Desktop Client

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-4CAF50?style=for-the-badge)
![License](https://img.shields.io/github/license/BlautaVi/team-room-desktop?style=for-the-badge)
![Contributions welcome](https://img.shields.io/badge/Contributions-Welcome-ff69b4?style=for-the-badge)

---

## 🧠 About the Project

**TeamRoom Desktop Client** — офіційний десктопний клієнт, створений на **Flutter**, для освітньої платформи **TeamRoom**.  
Мета — об’єднати всі інструменти дистанційного навчання в одному місці: курси, чати, завдання та відеоконференції.

> 🎯 “One platform. One community. One TeamRoom.”

---

## ✨ Key Features

| 💡 Функція | 📝 Опис |
|-------------|---------|
| 🧭 **Unified Dashboard** | Керуйте курсами, чатами та завданнями в одному вікні. |
| 📚 **Course Management** | Створюйте, приєднуйтесь і керуйте курсами. Підтримка ролей: Owner, Professor, Student. |
| 📁 **Learning Materials** | Завантажуйте, переглядайте та діліться матеріалами й медіафайлами. |
| 🧾 **Assignment Workflow** | Повний цикл роботи із завданнями — створення, відправлення, оцінювання. |
| 💬 **Real-Time Chat** | Миттєві приватні та групові повідомлення через STOMP over WebSocket. |
| 🎥 **Embedded Video Conferencing** | Підключайтеся до відеопар та лекцій без виходу з програми. |

---

## 🧩 Tech Stack

| 🔧 Layer | ⚙️ Technology |
|-----------|----------------|
| **Framework** | Flutter (Dart) |
| **UI** | Flutter Material Design |
| **State Management** | StatefulWidget, FutureBuilder |
| **API** | `http` package (RESTful API) |
| **Real-time** | `stomp_dart_client` (WebSocket) |
| **File Handling** | `file_picker`, custom `PCloudService` |
| **Video** | `webview_windows` (вбудований Jitsi/Zoom/WebRTC) |

---

## 🚀 Getting Started

### 🔹 Clone the Repository
```bash
git clone https://github.com/your-username/team-room-desktop.git
cd team-room-desktop
