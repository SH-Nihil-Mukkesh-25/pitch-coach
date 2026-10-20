# <p align="center">🎯 Pitch Coach</p>

<p align="center">
  <strong>Master Your Voice • Ace Your Interviews • Elevate Your Public Speaking</strong><br>
  <em>An AI-powered, real-time vocal analysis and speech coaching platform built with Flutter & FastAPI.</em>
</p>

<p align="center">
  <!-- Tech Badges -->
  <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://fastapi.tiangolo.com/"><img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" /></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python_3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" /></a>
  <a href="https://groq.com/"><img src="https://img.shields.io/badge/Groq_AI-F55036?style=for-the-badge&logo=openai&logoColor=white" alt="Groq AI" /></a>
  <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase_Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase Auth" /></a>
  <a href="https://sqlite.org/"><img src="https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" /></a>
  <a href="https://android.com/"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" /></a>
  <a href="https://apple.com/ios/"><img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" /></a>
</p>

---

## 📑 Table of Contents

- [🌟 Overview](#-overview)
- [✨ Core Capabilities](#-core-capabilities)
- [🎨 Iconography & Visual Icon Matrix](#-iconography--visual-icon-matrix)
  - [📱 Bottom Navigation Bar](#-bottom-navigation-bar)
  - [🏠 Home & Dashboard](#-home--dashboard)
  - [🎙️ Interview & Practice Studio](#️-interview--practice-studio)
  - [📊 Results & Analytics Breakdown](#-results--analytics-breakdown)
  - [📈 Progress, Growth & Milestones](#-progress-growth--milestones)
  - [🗓️ History & Session Archive](#️-history--session-archive)
  - [👤 Profile & Settings](#-profile--settings)
  - [🎓 Learning Hub & Lessons](#-learning-hub--lessons)
- [🛠️ Tech Stack & Architecture](#️-tech-stack--architecture)
  - [📱 Frontend (Flutter)](#-frontend-flutter)
  - [⚙️ Backend (FastAPI + Groq AI)](#️-backend-fastapi--groq-ai)
- [📁 Project Directory Structure](#-project-directory-structure)
- [🔌 API Endpoints Reference](#-api-endpoints-reference)
- [🚀 Quickstart & Setup Guide](#-quickstart--setup-guide)
  - [1. Backend Setup](#1-backend-setup)
  - [2. Flutter App Setup](#2-flutter-app-setup)
  - [3. Device Connection Modes](#3-device-connection-modes)
- [🎨 Design System & Color Palette](#-design-system--color-palette)
- [⚙️ Troubleshooting & Windows Build Fixes](#️-troubleshooting--windows-build-fixes)
- [🤝 Contributing & Community](#-contributing--community)
- [📄 License](#-license)

---

## 🌟 Overview

**Pitch Coach** is an intelligent mobile companion engineered to elevate your speech performance. Whether delivering a venture capital elevator pitch, presenting a keynote, or interviewing for your dream engineering job, Pitch Coach records your voice, analyzes linguistic metrics, extracts delivery cadence, highlights filler word frequencies, and provides actionable feedback powered by ultra-low-latency **Groq AI**.

> 💡 **Offline / Guest Mode Available**: Want to test Pitch Coach without hosting a backend? Pitch Coach includes built-in offline demo repositories and local evaluation fallbacks!

---

## ✨ Core Capabilities

| Feature | Icon | Description |
|:---|:---:|:---|
| **Intelligent Pitch Studio** | 🎙️ | High-fidelity audio recording with live waveform simulation, countdown timer, and prompt teleprompter. |
| **Instant Groq AI Feedback** | 🤖 | Multi-metric evaluation generating qualitative feedback, strengths, and areas of growth within seconds. |
| **Vocal Cadence & Pace** | ⚡ | Real-time Words-Per-Minute (WPM) tracking comparing your delivery to optimal conversational cadence. |
| **Filler Word Detection** | 🛑 | Pinpoints exact repetitions of *um*, *uh*, *like*, *you know*, *basically*, and *actually*. |
| **Interactive Metric Gauges** | 🎯 | Custom circular gauges and radial visualizers for clarity, tone, and overall confidence scores. |
| **Historical Trends & Charts** | 📈 | Line, bar, and area charts powered by `fl_chart` tracking speech improvements over weeks and months. |
| **Learning Hub & Video Guides** | 🎓 | Curated video lessons and interactive speech drills covering pitch pacing, posture, and hook formulas. |
| **Daily Smart Reminders** | ⏰ | Scheduled local notifications encouraging consistent daily speaking drills. |
| **Dual Theme System** | 🌓 | Seamlessly crafted Dark Navy (`#0F0F1A`) and Surface Light (`#F5F6FA`) modes with responsive typography. |

---

## 🎨 Iconography & Visual Icon Matrix

Pitch Coach features a carefully curated iconography system combining **Material Rounded Icons**, **Cupertino Glyphs**, and **Custom SVG assets**. Below is the complete catalog of every icon involved across the platform.

### 📱 Bottom Navigation Bar
The core dock of the mobile app provides one-tap routing across key views:

| Visual Icon | Flutter Identifier | Screen / Destination | Action / Purpose |
|:---:|:---|:---|:---|
| 🏠 | `Icons.home_rounded` | `HomeScreen` | Returns to Dashboard overview and active streak |
| 🗓️ | `Icons.history_rounded` | `HistoryScreen` | Opens timeline of all recorded practice sessions |
| 🎙️ | `Icons.mic_rounded` | `InterviewPracticeScreen` | **Elevated Center FAB**: Launches new practice session |
| 📊 | `Icons.insights_rounded` | `ProgressScreen` | Displays multi-session analytics and performance trends |
| 👤 | `Icons.person_rounded` | `ProfileScreen` | Displays user profile, AI preferences, and settings |

---

### 🏠 Home & Dashboard

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 🔔 | `Icons.notifications_none_rounded` | Top App Bar | Notification center and daily practice alerts |
| 🪑 | `Icons.event_seat_rounded` | Category Filter | Filters for Job Interview practice sessions |
| 📊 | `Icons.bar_chart_rounded` | Category Filter | Filters for Sales & Investor Pitch presentations |
| 🎙️ | `Icons.mic_rounded` | Category Filter | Filters for Casual & Speech delivery drills |
| ➕ | `Icons.add_rounded` | Quick Action Card | Quick launch button to start a fresh speech attempt |
| ➡️ | `Icons.chevron_right_rounded` | List Tile Cards | Navigates into detailed session cards or recommendations |
| 🔽 | `Icons.keyboard_arrow_down_rounded`| Dropdown Filters | Expands date range or session category selection |
| ⚡ | `Icons.bolt_rounded` | Streak Tracker | Indicates current active daily practice streak |
| 🏆 | `Icons.emoji_events_rounded` | Achievements Banner| Shows user badges and unlocked performance tiers |

---

### 🎙️ Interview & Practice Studio

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| ⬅️ | `Icons.chevron_left_rounded` | Studio Navigation | Exits practice studio back to Dashboard |
| 🌊 | `Icons.graphic_eq_rounded` | Sound Visualizer | Live dynamic waveform reacting during recording |
| 🔴 | `Icons.fiber_manual_record_rounded`| Recording Header | Pulsing red indicator signaling active audio capture |
| ⏸️ | `Icons.pause_rounded` | Control Dock | Temporarily pauses audio recording and timer |
| ▶️ | `Icons.play_arrow_rounded` | Control Dock | Resumes paused audio recording |
| ⏹️ | `Icons.stop_rounded` | Control Dock | Finalizes recording and sends audio for AI evaluation |
| ⏱️ | `Icons.timer_outlined` | Status Bar | Live duration countdown and elapsed time counter |
| 💡 | `Icons.tips_and_updates_rounded` | Teleprompter | Toggles contextual pitch prompts and scenario cues |

---

### 📊 Results & Analytics Breakdown

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 🎧 | `Icons.headphones_rounded` | Audio Player Card | Header icon for recorded speech playback container |
| ▶️ | `Icons.play_arrow_rounded` | Playback Bar | Starts playback of your recorded audio session |
| ⏸️ | `Icons.pause_rounded` | Playback Bar | Pauses audio playback at current position |
| 🗣️ | `Icons.record_voice_over_rounded` | Metric Card | Filler word frequency indicator (*um*, *like*, etc.) |
| 🏎️ | `Icons.speed_rounded` | Metric Card | Pacing and tempo analysis (Words Per Minute) |
| 📋 | `Icons.list_alt_rounded` | Metric Card | Speech structure, narrative flow, and organization |
| 😊 | `Icons.emoji_emotions_rounded` | Metric Card | Confidence, vocal energy, and tone perception |
| 💡 | `Icons.lightbulb_outline_rounded`| AI Insights | Key coaching tips, strengths, and recommendations |
| ⏰ | `Icons.access_time_rounded` | Metadata Pill | Displays total speaking duration for the session |
| ✅ | `Icons.check_circle_outline_rounded`| Strength Badge | Highlights verified positive delivery attributes |

---

### 📈 Progress, Growth & Milestones

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 🎙️ | `Icons.mic_rounded` | Stat Card | Total lifetime practice sessions completed |
| 😊 | `Icons.emoji_emotions_rounded` | Stat Card | Average confidence score across all sessions |
| 🔥 | `Icons.local_fire_department_rounded`| Stat Card | Daily streak counter for consecutive practice days |
| ⭐ | `Icons.star_rounded` | Stat Card | Peak overall score achieved across all sessions |
| ⬆️ | `Icons.arrow_upward_rounded` | Metric Deltas | Positive trend compared to previous evaluation period |
| ⬇️ | `Icons.arrow_downward_rounded` | Metric Deltas | Negative trend indicating area requiring attention |
| 📈 | `Icons.trending_up_rounded` | Growth Graph | Long-term performance curve moving upward |
| 📉 | `Icons.trending_down_rounded` | Growth Graph | Temporary dip in delivery clarity or pace |
| ➡️ | `Icons.trending_flat_rounded` | Growth Graph | Stable delivery metrics across consecutive attempts |

---

### 🗓️ History & Session Archive

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 📅 | `Icons.calendar_month_rounded` | Header Filter | Date-range picker for historical speech sessions |
| 🔍 | `Icons.search_rounded` | Search Bar | Filters history entries by title, category, or score |
| ✖️ | `Icons.clear_rounded` | Search Bar | Clears current search query text field |
| 🎙️ | `Icons.mic_none_rounded` | Empty State | Displayed when no practice recordings are logged |
| 📡 | `Icons.wifi_off_rounded` | Network Banner | Offline indicator showing local cache fallback mode |

---

### 👤 Profile & Settings

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 👤 | `Icons.person_outline_rounded` | Settings Section | User profile details, name, and speaking objectives |
| 🪪 | `Icons.badge_outlined` | Profile Setup | Full name and display name input field icon |
| 💼 | `Icons.work_outline_rounded` | Profile Setup | Professional role / student occupation input field |
| ✉️ | `Icons.email_outlined` | Profile Setup | User contact email address input field |
| 🎯 | `Icons.ads_click_rounded` | Goals Setup | Target score and speaking goals selection |
| 🧠 | `Icons.psychology_outlined` | Preferences | AI feedback strictness (Gentle, Balanced, Strict) |
| 🔘 | `Icons.radio_button_checked` | Option Select | Active selection for feedback style or difficulty |
| 🔔 | `Icons.notifications_none_rounded`| Settings Tile | Toggle daily speaking reminders and push alerts |
| ⏰ | `Icons.access_time_rounded` | Notification Modal | Configures daily reminder delivery time |
| 🔕 | `Icons.notifications_off_outlined`| Notification Modal | Disables automated scheduled reminder alerts |
| 🏁 | `Icons.flag_outlined` | Settings Tile | Targets, milestones, and speaking goals config |
| 🌙 | `Icons.dark_mode_outlined` | Theme Switcher | Dark Mode / Light Mode theme toggle button |
| 🌐 | `Icons.language_rounded` | Settings Tile | Spoken language and accent regionalization |
| ❓ | `Icons.help_outline_rounded` | Support Section | Frequently Asked Questions and documentation |
| 💬 | `Icons.chat_bubble_outline_rounded`| Support Section | Send direct feedback to the development team |
| 👍 | `Icons.thumb_up_alt_outlined` | Support Section | App Store / Play Store rating trigger |
| ℹ️ | `Icons.info_outline_rounded` | App Info Tile | Software version, build number, and open source licenses |
| 🚪 | `Icons.logout_rounded` | Account Action | Safely signs out of account and clears session tokens |

---

### 🎓 Learning Hub & Lessons

| Visual Icon | Flutter Identifier | UI Location | Description |
|:---:|:---|:---|:---|
| 🎓 | `Icons.school_rounded` | Hub Header | Public speaking curriculum and interactive drills |
| 🎬 | `Icons.video_library_rounded` | Lesson List | Multimedia video guides covering posture and pitch |
| ▶️ | `Icons.play_arrow_rounded` | Video Player | Starts streaming instructional communication video |
| ⏸️ | `Icons.pause_rounded` | Video Player | Pauses video player stream |
| 💡 | `Icons.lightbulb_rounded` | Lesson Summary | High-yield speaking takeaway pointers |
| ✅ | `Icons.check_circle_rounded` | Lesson Checklist | Mark actionable drills as completed |
| 🎙️ | `Icons.mic_rounded` | Action Prompt | "Practice This Lesson Now" CTA button |

---

## 🛠️ Tech Stack & Architecture

```
                                  ┌──────────────────────────────┐
                                  │   Flutter Mobile App (UI)    │
                                  │  Material 3 • GoRouter • Dio  │
                                  └──────────────┬───────────────┘
                                                 │
                                     HTTP / REST API (JSON)
                                                 │
                                  ┌──────────────▼───────────────┐
                                  │   FastAPI Backend (Python)   │
                                  │    Auth • Sessions • Stats   │
                                  └──────┬───────────────┬───────┘
                                         │               │
                 ┌───────────────────────┴──┐         ┌──┴────────────────────────┐
                 │  SQLite / SQLAlchemy     │         │   Groq AI Cloud Engine    │
                 │  Local DB: pitch_coach.db│         │   LLaMA-3 Evaluation LLM  │
                 └──────────────────────────┘         └───────────────────────────┘
```

### 📱 Frontend (Flutter)
- **Dart SDK**: `^3.10.0`
- **Architecture**: Feature-first modular pattern (`lib/features/*` + `lib/core/*`)
- **State Management**: `provider: ^6.1.5+1` for reactive UI state & auth sync
- **Navigation**: `go_router: ^17.3.0` with custom ease-out slide & fade transitions
- **Audio Stack**: `record: ^5.2.0` (microphone capture) + `audioplayers: ^6.1.0` (playback)
- **Data Charts**: `fl_chart: ^1.2.0` (responsive line, bar, and gauge curves)
- **Typography & Assets**: `google_fonts: ^8.2.1`, `flutter_svg: ^2.3.0`, `cupertino_icons: ^1.0.8`
- **Security & Storage**: `flutter_secure_storage: ^9.2.4` (Keystore / Keychain JWT persistence)
- **Auth Integrations**: `firebase_core: ^3.8.1`, `firebase_auth: ^5.3.4`, `google_sign_in: ^6.2.2`
- **Video & Notifications**: `video_player: ^2.9.2`, `flutter_local_notifications: ^18.0.1`

### ⚙️ Backend (FastAPI + Groq AI)
- **Engine**: `fastapi==0.115.5` with ASGI runner `uvicorn==0.32.1`
- **ORM & Database**: `sqlalchemy==2.0.36` backed by SQLite (`pitch_coach.db`)
- **AI Speech Inference**: `groq==0.13.0` connecting to ultra-fast Groq LPU inference
- **Security & Hashing**: `python-jose==3.3.0` (JWT token creation), `passlib==1.7.4`, `bcrypt==4.0.1`
- **File Ingestion**: `python-multipart==0.0.12`, `aiofiles==24.1.0`

---

## 📁 Project Directory Structure

```
pitch-coach/
├── 📄 README.md                        # Project documentation & icon guide
├── 📄 pubspec.yaml                     # Flutter package dependencies & assets
├── 📄 firebase.json                    # Firebase hosting & CLI configuration
├── 📄 analysis_options.yaml            # Dart static analysis & lint configurations
│
├── 📂 assets/                          # Static project assets
│   └── 📂 images/
│       ├── 🖼️ pitch_coach_logo.png     # Pitch Coach official brand icon
│       └── 🖼️ empty_history.png        # Empty state history placeholder
│
├── 📂 backend/                         # FastAPI Python REST API Server
│   ├── 🐍 main.py                      # FastAPI entrypoint, middleware, and router mounts
│   ├── 🐍 config.py                    # Environment configuration & settings
│   ├── 🐍 database.py                  # SQLAlchemy engine & SQLite session factory
│   ├── 🐍 models.py                    # ORM models (User, Session, Feedback, Stats)
│   ├── 🐍 schemas.py                   # Pydantic request & response validation schemas
│   ├── 📄 requirements.txt             # Python dependencies manifest
│   ├── 📜 start.bat                    # One-click Windows startup script
│   ├── 📂 auth/                        # Registration, login, and JWT token routes
│   ├── 📂 users/                       # Profile management & preferences
│   ├── 📂 sessions/                    # Audio recording upload & Groq AI evaluation
│   ├── 📂 stats/                       # User trend analytics & aggregated scores
│   └── 📂 achievements/                # Badges, milestones, and streak tracking
│
└── 📂 lib/                             # Flutter Mobile Application
    ├── 📱 main.dart                    # App initialization, theme injection & runApp
    ├── ⚙️ firebase_options.dart         # Multi-platform Firebase configurations
    │
    ├── 📂 core/                        # Reusable foundational modules
    │   ├── 📂 config/                  # App constants & API base URL configurations
    │   ├── 📂 models/                  # Session, Lesson, and Analytics models
    │   ├── 📂 providers/               # Global state providers (User, Theme, Stats)
    │   ├── 📂 repositories/            # Network repositories & local fallback mocks
    │   ├── 📂 router/                  # GoRouter configuration & page transitions
    │   ├── 📂 services/                # Audio recording, storage, and notification services
    │   ├── 📂 theme/                   # AppColors, AppTextStyles, and ThemeData
    │   └── 📂 widgets/                 # BottomNavBar, CircularGaugePainter, MetricCards
    │
    └── 📂 features/                    # Feature-driven modular screens
        ├── 📂 auth/                    # Login, Sign-up, and OAuth screens
        ├── 📂 demo/                    # Interactive Design System showcase
        ├── 📂 history/                 # Session history, search & filter archive
        ├── 📂 home/                    # Central dashboard & quick practice launcher
        ├── 📂 interview/               # Audio recording practice room & teleprompter
        ├── 📂 learn/                   # Curriculum lessons & video player drills
        ├── 📂 onboarding/              # First-launch onboarding walkthrough
        ├── 📂 profile/                 # Profile setup, goals & feedback preference
        ├── 📂 progress/                # Visual charts, score radar & metrics
        └── 📂 results/                 # Post-session evaluation & audio playback
```

---

## 🔌 API Endpoints Reference

The FastAPI backend exposes interactive OpenAPI documentation at `http://localhost:8000/docs`.

| Method | Endpoint | Description | Auth Required |
|:---:|:---|:---|:---:|
| `GET` | `/health` | System health check & API version | ❌ No |
| `POST` | `/auth/register` | Register new user with email & password | ❌ No |
| `POST` | `/auth/login` | Authenticate user & receive JWT Bearer token | ❌ No |
| `GET` | `/auth/me` | Retrieve profile of authenticated user | 🔒 Yes |
| `GET` | `/users/profile` | Get current user's profile and goal metrics | 🔒 Yes |
| `PUT` | `/users/profile` | Update profile goals, role, and AI preferences | 🔒 Yes |
| `POST` | `/sessions/upload` | Upload audio recording (`.m4a`/`.wav`) for analysis | 🔒 Yes |
| `GET` | `/sessions/` | List past practice sessions with pagination | 🔒 Yes |
| `GET` | `/sessions/{session_id}`| Get in-depth AI evaluation, scores, and transcript | 🔒 Yes |
| `GET` | `/stats/summary` | Get summary cards (average score, total sessions) | 🔒 Yes |
| `GET` | `/stats/trends` | Historical performance metrics for `fl_chart` graphs | 🔒 Yes |
| `GET` | `/achievements/` | List unlocked achievements and current streak | 🔒 Yes |

---

## 🚀 Quickstart & Setup Guide

### 1. Backend Setup

```powershell
# 1. Navigate to the backend directory
cd backend

# 2. Create and activate a Python virtual environment
python -m venv venv
venv\Scripts\activate

# 3. Install required Python packages
pip install -r requirements.txt

# Prerequisite: Install FFmpeg (required for audio decoding of .m4a, .mp3, .wav, .webm)
# Windows: choco install ffmpeg  OR  winget install Gyan.FFmpeg
# macOS:   brew install ffmpeg
# Linux:   sudo apt-get install ffmpeg

# 4. Create your environment file from template
copy .env.example .env

# 5. Open .env and add your Groq API Key:
# GROQ_API_KEY=gsk_your_actual_groq_key_here

# 6. Launch the FastAPI server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
The server will start at `http://localhost:8000` (API docs at `http://localhost:8000/docs`).

---

### 2. Flutter App Setup

Open a new terminal window in the root directory:

```powershell
# 1. Ensure you are in the project root
cd pitch-coach

# 2. Fetch Flutter packages
flutter pub get

# 3. Verify Flutter environment health
flutter doctor
```

---

### 3. Device Connection Modes

Choose your launch target:

#### 📱 Option A: Android Emulator
Android Emulators access your host machine's localhost via the loopback IP `10.0.2.2`:
```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### 📲 Option B: Physical Device (Same Wi-Fi)
Find your computer's local IP using `ipconfig` (e.g. `192.168.1.50`):
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

#### 💻 Option C: Desktop / Web
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

#### 🚀 Option D: Guest Mode (Instant Demo)
Run directly without any backend arguments. Pitch Coach automatically detects the environment and loads rich local mock data:
```powershell
flutter run
```

---

## 🎨 Design System & Color Palette

Pitch Coach employs a tailored HSL-balanced color system providing visual clarity and reduced eye fatigue:

| Color Token | Hex Code | Visual Sample | Usage |
|:---|:---:|:---:|:---|
| `AppColors.background` | `#0F0F1A` | ![#0F0F1A](https://via.placeholder.com/15/0F0F1A/000000?text=+) | Dark theme scaffold background |
| `AppColors.surfaceLight` | `#F5F6FA` | ![#F5F6FA](https://via.placeholder.com/15/F5F6FA/000000?text=+) | Light theme scaffold surface |
| `AppColors.cardDark` | `#17152E` | ![#17152E](https://via.placeholder.com/15/17152E/000000?text=+) | Dark container and card surface |
| `AppColors.primaryPurple` | `#6C5CE7` | ![#6C5CE7](https://via.placeholder.com/15/6C5CE7/000000?text=+) | Primary brand accent & active states |
| `AppColors.primaryPurpleLight` | `#8B5CF6` | ![#8B5CF6](https://via.placeholder.com/15/8B5CF6/000000?text=+) | Gradient end color & highlights |
| `AppColors.accentBlue` | `#3B82F6` | ![#3B82F6](https://via.placeholder.com/15/3B82F6/000000?text=+) | Secondary metrics & session cards |
| `AppColors.accentGreen` | `#10B981` | ![#10B981](https://via.placeholder.com/15/10B981/000000?text=+) | Success states, peak scores & streaks |
| `AppColors.warningAmber` | `#F5A623` | ![#F5A623](https://via.placeholder.com/15/F5A623/000000?text=+) | Moderate pacing & filler alerts |
| `AppColors.dangerRed` | `#E85C5C` | ![#E85C5C](https://via.placeholder.com/15/E85C5C/000000?text=+) | Stop button, recording pulse & errors |

---

## ⚙️ Troubleshooting & Windows Build Fixes

### ⚠️ Windows Cross-Drive Kotlin Compilation Error
If your project is located on a secondary drive (e.g. `D:`) while the Gradle/Pub cache resides on `C:`, Kotlin may throw an `IllegalArgumentException`:

**Fix**: Confirm `android/gradle.properties` contains:
```properties
kotlin.incremental=false
kotlin.incremental.usePreciseJavaTracking=false
```

### 🎙️ Audio Recording Permissions
If audio recording fails to start:
- **Android**: Ensure `android/app/src/main/AndroidManifest.xml` includes:
  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  ```
- **Physical Device**: Go to **Settings > Apps > Pitch Coach > Permissions** and ensure **Microphone** is set to **Allow**.

### 🔒 CORS / Network Connection Refused
If requests fail when testing on a physical phone:
- Check Windows Defender Firewall to ensure Python / port `8000` allows incoming connections on Private networks.
- Confirm both your phone and PC are connected to the exact same Wi-Fi network.

---

## 🧪 Development Commands

```powershell
# Analyze Dart code for style & lint warnings
flutter analyze

# Execute all frontend test suites
flutter test

# Build debug APK for testing
flutter build apk --debug

# Build optimized production release APK
flutter build apk --release
```

---

## 🤝 Contributing & Community

Contributions make the open-source community an inspiring place to learn, create, and build:

1. **Fork the Project**
2. **Create your Feature Branch** (`git checkout -b feature/AmazingPitchFeature`)
3. **Commit your Changes** (`git commit -m 'Add some AmazingPitchFeature'`)
4. **Push to the Branch** (`git push origin feature/AmazingPitchFeature`)
5. **Open a Pull Request**

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

<p align="center">
  Made with ❤️ for speakers, founders, and interviewees worldwide.
</p>
