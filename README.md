# <p align="center"> Pitch Coach</p>

<p align="center">
  <strong>Master Your Voice • Ace Your Presentations • Conquer Q&A Cross-Examinations</strong><br>
  <em>An enterprise-grade, multimodal AI speech coaching and presentation intelligence platform built with Flutter, FastAPI, Groq LPU, and MongoDB.</em>
</p>

<p align="center">
  <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter_3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart_3.10+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://fastapi.tiangolo.com/"><img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" /></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python_3.12-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" /></a>
  <a href="https://groq.com/"><img src="https://img.shields.io/badge/Groq_LPU_Inference-F55036?style=for-the-badge&logo=openai&logoColor=white" alt="Groq LPU" /></a>
  <a href="https://www.mongodb.com/"><img src="https://img.shields.io/badge/MongoDB_Atlas-47A248?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB" /></a>
  <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase_Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase Auth" /></a>
  <a href="https://ffmpeg.org/"><img src="https://img.shields.io/badge/FFmpeg_DSP-007808?style=for-the-badge&logo=ffmpeg&logoColor=white" alt="FFmpeg" /></a>
</p>


---

## 🌟 Overview

**Pitch Coach** is an AI-powered public speaking and presentation intelligence platform. Designed for startup founders pitching to venture capitalists, engineers defending architecture at hackathons, researchers delivering academic defenses, and professionals preparing for high-stakes interviews.

Pitch Coach combines **digital signal processing (DSP)** for acoustic telemetry (fundamental frequency $F_0$ pitch variation, energy curves, monotone classification) with **Groq ultra-fast LPU inference** and **computer vision slide parsing** (PyMuPDF). The system analyzes vocal acoustics, audits deck narrative arcs against target audience expectations, generates actionable speech cues, conducts live timed rehearsals, and runs simulated Q&A cross-examinations.

> 💡 **Offline / Guest Mode Available**: Pitch Coach incorporates zero-dependency in-memory mock repositories and offline SQLite caching, allowing the application to be evaluated out of the box without active cloud credentials.

---

## ✨ Core Capabilities

| Pillar | Engineering Highlights | Technical Benefit |
| :--- | :--- | :--- |
| **🎙️ Intelligent Speech Studio** | High-frequency PCM sampling, dynamic waveform visualizer, teleprompter scenarios, and active duration countdown. | Low-latency audio capture with live visual volume dynamics. |
| **⚡ Acoustic DSP & Vocal Delivery** | NumPy-based autocorrelation fundamental frequency ($F_0$) pitch standard deviation, RMS energy curves, and volume consistency scoring. | Quantifies vocal enthusiasm and flags monotone delivery scientifically. |
| **🛑 Silence Guard & VAD** | Voice Activity Detection (VAD) energy thresholding with a mandatory 1.0s active speech gate. | Protects LLMs from hallucinating on empty noise, background hum, or coughs. |
| **🖼️ Slide Coach (Deck Vision)** | PyMuPDF slide rasterization, text density calculation, visual hierarchy audits, and weak title detection. | Identifies cognitive slide overload and slide layout anti-patterns. |
| **🎯 Audience-Adaptive Coaching** | Dynamic evaluation strategy switching between **Hackathon Judges**, **Investors**, **Academic Review**, **Clients**, and **General Audience**. | Eliminates false "Missing Ask" warnings on technical decks; assesses prototypes and tech architecture appropriately. |
| **💬 Speech-Ready Cue Generation** | Active-verb talking points, word-for-word pitch scripts, and smooth transition hooks with debounced persistence. | Prevents reading slides verbatim; formats speaking cues cleanly without UI text truncation. |
| **⏱️ Rehearsal Mode & Pacing Alerts** | Real-time slide transition recorder, speaking rate telemetry (WPM vs target band), and slide pacing alerts. | Trains presenters to respect time budgets per slide. |
| **❓ Audience Q&A Simulator** | AI-driven hostile/probing question generator with answer scoring on relevance, accuracy, and confidence. | Prepares presenters for tough cross-examinations before stepping on stage. |
| **📈 Multi-Session Progress Tracking** | `fl_chart` responsive analytics, confidence radar, streak gamification, and fractional-tick suppressed trend curves. | Visualizes long-term growth across clarity, cadence, and tone. |

---

## 📱 Application Screenshots & Feature Walkthrough

Explore the complete user journey and interactive UI modules of Pitch Coach. The screens are organized into functional modules below, each featuring responsive 3-column previews with detailed descriptions of their role in presentation coaching.

### 🔐 1. Authentication & Security
*Secure onboarding, account registration, and credential validation.*

| <kbd>&nbsp;🚀&nbsp;Splash&nbsp;Launch&nbsp;</kbd> | <kbd>&nbsp;🔑&nbsp;Account&nbsp;Login&nbsp;</kbd> | <kbd>&nbsp;📝&nbsp;Sign&nbsp;Up&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/splash_screen.png" alt="Splash Launch" width="100%" /> | <img src="screenshots_app/login.png" alt="Account Login" width="100%" /> | <img src="screenshots_app/signup.png" alt="Sign Up" width="100%" /> |
| **Splash Launch**<br>Brand splash initializing local caches, checking JWT expiration, and routing to auth or home. | **Account Login**<br>Secure email & password authentication with encrypted token storage and offline guest fallback. | **User Registration**<br>New speaker account creation interface with form validation and profile initialization. |

<br/>

### 🏠 2. Access & Central Dashboard
*One-tap OAuth entry, presentation statistics, and module quick-launch cards.*

| <kbd>&nbsp;🌐&nbsp;Google&nbsp;SSO&nbsp;</kbd> | <kbd>&nbsp;📊&nbsp;Dashboard&nbsp;Top&nbsp;</kbd> | <kbd>&nbsp;🎯&nbsp;Quick&nbsp;Actions&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/google_login.png" alt="Google SSO" width="100%" /> | <img src="screenshots_app/home_screen1.png" alt="Dashboard Top" width="100%" /> | <img src="screenshots_app/home_screen2.png" alt="Quick Actions" width="100%" /> |
| **Google OAuth SSO**<br>One-tap federated single sign-on dialog facilitating rapid password-less access. | **Home Dashboard (Top)**<br>Personalized greeting, current streak counter, and weekly practice time summaries. | **Quick Actions (Hub)**<br>Module launchers for Slide Coach, Speech Studio, recent rehearsal sessions, and targeted drills. |

<br/>

### 📑 3. Slide Coach — Deck Ingestion & Background Audits
*Multimodal PDF pitch deck ingestion, audience strategy selection, and async background processing.*

| <kbd>&nbsp;📁&nbsp;Deck&nbsp;Upload&nbsp;</kbd> | <kbd>&nbsp;🎯&nbsp;Target&nbsp;Audience&nbsp;</kbd> | <kbd>&nbsp;⏳&nbsp;Background&nbsp;Task&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/analyse_deck.png" alt="Deck Upload" width="100%" /> | <img src="screenshots_app/analyse_deck2.png" alt="Target Audience" width="100%" /> | <img src="screenshots_app/pitch_deck_running_inbackground.png" alt="Background Task" width="100%" /> |
| **Deck Selector**<br>MediaStore SAF document selector for uploading presentation slide decks. | **Target Audience Selector**<br>Customizes AI evaluation criteria for Hackathons, Investors, Academics, Clients, or General Audiences. | **Background Task Worker**<br>Non-blocking worker screen executing slide rasterization and LLM audits asynchronously. |
| <kbd>&nbsp;🔔&nbsp;Push&nbsp;Alert&nbsp;</kbd> | <kbd>&nbsp;⚡&nbsp;Resume&nbsp;Task&nbsp;</kbd> | <kbd>&nbsp;📋&nbsp;Slide&nbsp;Audits&nbsp;</kbd> |
| <img src="screenshots_app/notification_after_completion_of_pitch_deck_in_background.png" alt="Push Alert" width="100%" /> | <img src="screenshots_app/pitch_deck_after_running_in_background.png" alt="Resume Task" width="100%" /> | <img src="screenshots_app/pitch_deck_analyses.png" alt="Slide Audits" width="100%" /> |
| **System Push Notification**<br>Heads-up alert notifying the user the moment background multimodal analysis completes. | **Task Resume Card**<br>Live dashboard card with one-tap navigation to review completed presentation analysis. | **Deck Diagnostic Summary**<br>High-level slide audits displaying overall narrative score, text density, and slide anti-patterns. |

<br/>

### 💡 4. Slide Coach — Cue Cards, Rehearsal Mode & Q&A Prep
*Slide-by-slide speaker cue cards, live timed presentation rehearsals, and tough cross-examination prep.*

| <kbd>&nbsp;🎯&nbsp;Slide&nbsp;1:&nbsp;Hook&nbsp;</kbd> | <kbd>&nbsp;💡&nbsp;Slide&nbsp;2:&nbsp;Solution&nbsp;</kbd> | <kbd>&nbsp;📈&nbsp;Slide&nbsp;3:&nbsp;Traction&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/pitch_deck_result1.png" alt="Slide 1: Hook" width="100%" /> | <img src="screenshots_app/pitch_deck_result2.png" alt="Slide 2: Solution" width="100%" /> | <img src="screenshots_app/pitch_deck_result3.png" alt="Slide 3: Traction" width="100%" /> |
| **Slide 1: Problem & Hook**<br>Slide preview with word-for-word pitch scripts, active talking points, and opening timing budget. | **Slide 2: Solution Architecture**<br>Technical architecture speaking cues, core value propositions, and transition hooks. | **Slide 3: Market & Traction**<br>Metric emphasis cues, visual data delivery tips, and pacing guidance for graphs. |
| <kbd>&nbsp;🚀&nbsp;Slide&nbsp;4:&nbsp;The&nbsp;Ask&nbsp;</kbd> | <kbd>&nbsp;⏱️&nbsp;Live&nbsp;Rehearsal&nbsp;</kbd> | <kbd>&nbsp;❓&nbsp;Q&A&nbsp;Cross-Exam&nbsp;</kbd> |
| <img src="screenshots_app/pitch_deck_result4.png" alt="Slide 4: The Ask" width="100%" /> | <img src="screenshots_app/pitch_deck_result_prep_talk.png" alt="Live Rehearsal" width="100%" /> | <img src="screenshots_app/pitch_deck_question_prep.png" alt="Q&A Cross-Exam" width="100%" /> |
| **Slide 4: Business Model & Ask**<br>Closing call-to-action scripts, investment ask delivery tips, and contact slide wrap-up. | **Live Rehearsal Mode**<br>Interactive presentation timer with slide transition logging and pacing telemetry. | **Hostile Q&A Simulator**<br>AI-generated audience cross-examination with anticipated hard questions and model answers. |

<br/>

### 🎙️ 5. Speech Studio — Vocal DSP & Acoustic Telemetry
*Acoustic signal processing, fundamental frequency ($F_0$) variation, pacing telemetry, and AI delivery advice.*

| <kbd>&nbsp;📜&nbsp;Prompt&nbsp;Script&nbsp;</kbd> | <kbd>&nbsp;🎙️&nbsp;Recording&nbsp;Studio&nbsp;</kbd> | <kbd>&nbsp;📊&nbsp;Speech&nbsp;Score&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/voice_feature.png" alt="Prompt Script" width="100%" /> | <img src="screenshots_app/voice_feature2.png" alt="Recording Studio" width="100%" /> | <img src="screenshots_app/voice_feature3_result1.png" alt="Speech Score" width="100%" /> |
| **Speech Script Catalog**<br>Teleprompter prompt library featuring elevator pitches, technical talks, and custom speech entry. | **Active Recording Studio**<br>Low-latency recording view with real-time waveform dynamics and duration tracking. | **Vocal Delivery Scorecard**<br>Composite speech rating summarizing overall score, speaking rate (WPM), and filler word count. |

| <kbd>&nbsp;⚡&nbsp;Acoustic&nbsp;DSP&nbsp;</kbd> | <kbd>&nbsp;💡&nbsp;Delivery&nbsp;Advice&nbsp;</kbd> |
| :---: | :---: |
| <img src="screenshots_app/voice_feature3_result2.png" alt="Acoustic DSP" width="100%" /> | <img src="screenshots_app/voice_feature3_result3.png" alt="Delivery Advice" width="100%" /> |
| **Acoustic Pitch & Monotone DSP**<br>Scientific pitch telemetry displaying fundamental frequency ($F_0$) variation and monotone delivery alerts. | **Personalized Speech Coaching**<br>Actionable feedback detailing tips to enhance vocal modulation, pause control, and resonance. |

<br/>

### 📈 6. Progress Tracking, History & Profile Management
*Longitudinal speaking analytics, radar skill breakdown, rehearsal archives, and user configurations.*

| <kbd>&nbsp;📈&nbsp;Practice&nbsp;Stats&nbsp;</kbd> | <kbd>&nbsp;🕸️&nbsp;Skills&nbsp;Radar&nbsp;</kbd> | <kbd>&nbsp;🔥&nbsp;Streak&nbsp;Badges&nbsp;</kbd> |
| :---: | :---: | :---: |
| <img src="screenshots_app/progress_page1.png" alt="Practice Stats" width="100%" /> | <img src="screenshots_app/progress_page2.png" alt="Skills Radar" width="100%" /> | <img src="screenshots_app/progress_page3.png" alt="Streak Badges" width="100%" /> |
| **Practice Overview & Stats**<br>Long-term practice tracking showing total sessions, confidence curves, and average score trends. | **Skills Radar Analysis**<br>Multi-dimensional radar chart breaking down performance across Clarity, Cadence, Tone, and Energy. | **Streak & Achievement Badges**<br>Gamified daily practice streaks, weekly milestone challenges, and unlockable mastery trophies. |
| <kbd>&nbsp;🗂️&nbsp;Session&nbsp;History&nbsp;</kbd> | <kbd>&nbsp;👤&nbsp;User&nbsp;Profile&nbsp;</kbd> | <kbd>&nbsp;⚙️&nbsp;App&nbsp;Settings&nbsp;</kbd> |
| <img src="screenshots_app/History_page.png" alt="Session History" width="100%" /> | <img src="screenshots_app/profile_screen1.png" alt="User Profile" width="100%" /> | <img src="screenshots_app/profile_screen2.png" alt="App Settings" width="100%" /> |
| **Rehearsal Audit Archive**<br>Chronological ledger of analyzed decks and recorded vocal sessions with full audit summaries. | **Speaker Profile Card**<br>User bio, presenter rank, cumulative rehearsal hours, and account credential management. | **Settings & Configuration**<br>Preferences menu for API endpoint configuration, local cache management, and account sign-out. |

---

## 🏗️ System Architecture

Pitch Coach follows a clean, decoupled client-server architecture:

<p align="center">
  <img src="assets/architectural_diagram.png" alt="Pitch Coach System Architecture" width="100%" />
</p>

<details>
<summary><b>View Architecture Specification & Mermaid Definition</b></summary>

```mermaid
graph TB
    subgraph Client["Flutter Mobile Client (Material 3 + Impeller)"]
        UI["Presentation & Coaching UI<br/>(GoRouter + Material 3)"]
        State["Reactive State Layer<br/>(Provider: SlideCoach, Stats, User)"]
        AudioRec["Audio Capture Engine<br/>(package:record • AAC/M4A/WAV)"]
        FilePick["Document Selector<br/>(package:file_picker • MediaStore SAF)"]
        LocalCache["Local Persistence<br/>(sqflite • flutter_secure_storage)"]
    end

    subgraph Network["Transport & Security"]
        REST["HTTP / REST API (JSON + Multipart Form)"]
        Auth["Bearer JWT Authentication<br/>(python-jose + Firebase Auth)"]
    end

    subgraph Backend["FastAPI High-Performance Server"]
        Router["FastAPI Application Routers<br/>(/sessions, /slides, /users, /stats)"]
        
        subgraph AudioDSP["Audio Processing Subsystem"]
            FFmpeg["FFmpeg Streaming Subprocess<br/>(Format normalization to 16kHz Mono PCM)"]
            SilenceGuard["Silence Guard & VAD<br/>(Active Speech Duration Gate >= 1.0s)"]
            VocalDSP["NumPy Acoustic Engine<br/>(Pitch F0 StdDev, Volume Score, Energy Curve)"]
        end

        subgraph SlidePipeline["Multimodal Slide Engine"]
            PdfRaster["PyMuPDF Rasterizer<br/>(PDF/PPTX -> PNG Slide Renderings)"]
            VisionAudit["Slide Layout & Density Critic<br/>(Hierarchy, Text Overload, Title Punch)"]
            AudienceAdapter["Audience Adaptation Engine<br/>(Judges vs Investors vs Academic vs Clients)"]
        end
    end

    subgraph External["Persistence & AI Inference Engines"]
        Mongo[("MongoDB Atlas Database<br/>(Users, Sessions, Slide Decks, Metrics)")]
        Groq["Groq Cloud LPU Inference<br/>(Whisper-large-v3 STT + LLaMA-3.3-70b-versatile)"]
    end

    UI --> State
    State --> AudioRec
    State --> FilePick
    State --> LocalCache
    State --> REST

    REST --> Auth --> Router
    Router --> AudioDSP
    Router --> SlidePipeline

    FFmpeg --> SilenceGuard --> VocalDSP
    PdfRaster --> VisionAudit --> AudienceAdapter

    AudioDSP --> Groq
    SlidePipeline --> Groq
    Router --> Mongo
```

</details>

---

## 🔄 Deep-Dive Execution Flows

### 1. Vocal DSP & Speech Analysis Pipeline

When the presenter records their pitch in the studio, the audio follows an optimized multi-stage validation and digital signal processing pipeline:

<p align="center">
  <img src="assets/1Vocal%20DSP%20%26%20Speech%20Analysis%20Pipeline.png" alt="Vocal DSP and Speech Analysis Pipeline" width="100%" />
</p>

<details>
<summary><b>View Sequence Execution Flow (Mermaid Definition)</b></summary>

```mermaid
sequenceDiagram
    autonumber
    actor Presenter as User (Mobile App)
    participant Client as Flutter Audio Engine
    participant API as FastAPI Backend
    participant DSP as Audio DSP & Silence Guard
    participant Groq as Groq AI LPU Cloud
    participant DB as MongoDB Atlas

    Presenter->>Client: Tap Record & Speak Pitch
    Client->>Client: Stream live waveform dynamics
    Presenter->>Client: Tap Stop
    Client->>API: POST /sessions/upload (multipart audio file)
    
    API->>DSP: Stream audio into FFmpeg subprocess
    DSP->>DSP: Normalize to 16kHz 16-bit Mono Raw PCM
    DSP->>DSP: Evaluate Voice Activity (Silence Guard)
    
    alt Active Speech < 1.0s
        DSP-->>API: Reject with 400 (Insufficient Speech Burst)
        API-->>Client: Alert "Speech too short or silent"
    else Active Speech >= 1.0s
        par Acoustic Telemetry Extraction
            DSP->>DSP: Compute Autocorrelation Pitch (F0) StdDev
            DSP->>DSP: Generate RMS Energy Curve & Volume Consistency
            DSP->>DSP: Classify Monotone (Pitch StdDev < 12Hz)
        and Speech-to-Text & Semantic Evaluation
            API->>Groq: Transcribe via Whisper-large-v3
            Groq-->>API: Verbatim Transcript with Timestamps
            API->>API: Match acoustic & lexical filler words
            API->>Groq: Request Structured Evaluation (LLaMA-3.3-70b)
            Groq-->>API: Strengths, Growth Areas, Metric Scores
        end
        API->>DB: Persist Session Document & Analytics
        API-->>Client: Complete JSON Evaluation Payload
        Client-->>Presenter: Render Results, Gauges & Metric Breakdown
    end
```

</details>

---

### 2. Multimodal Slide Coach AI Pipeline

For slide deck coaching, the platform executes slide rasterization, visual criticism, target-audience alignment, talking point generation, and live rehearsal synchronization:

<p align="center">
  <img src="assets/2%20Multimodal%20Slide%20Coach%20AI%20Pipeline.png" alt="Multimodal Slide Coach AI Pipeline" width="100%" />
</p>

<details>
<summary><b>View Sequence Execution Flow (Mermaid Definition)</b></summary>

```mermaid
sequenceDiagram
    autonumber
    actor Presenter as User (Mobile App)
    participant Client as Flutter Deck Review UI
    participant API as FastAPI Slide Router
    participant PyMu as PyMuPDF Engine
    participant Groq as Groq AI (Deck Vision)
    participant DB as MongoDB Atlas

    Presenter->>Client: Select PDF/PPTX Deck & Target Audience
    Client->>API: POST /slides/upload (File + Audience + Time Limit)
    API->>DB: Initialize Deck Document (status: processing)
    
    API->>PyMu: Rasterize pages into PNG slides (300 DPI)
    PyMu-->>API: Extracted raw text, visual bounding boxes & images
    
    API->>API: Apply Audience Evaluation Strategy (Pillars & Rules)
    API->>API: Calculate text density & visual hierarchy per slide
    
    API->>Groq: Request Structured JSON Coaching (LLaMA-3.3-70b)
    Note over API,Groq: Injects Audience Lens, Emphasize/Avoid rules,<br/>Actionable Talking Points, Word-for-Word Script
    Groq-->>API: Full Deck Coaching JSON
    
    API->>DB: Store SlideCoaching models & DeckSummary
    API-->>Client: Analysis Complete (status: done)
    
    Client-->>Presenter: Render Story Arc, Pillars, Cue Cards & Audio Intel
    
    opt Live Rehearsal
        Presenter->>Client: Rehearse Presentation with Deck Carousel
        Client->>Client: Log slide transition timestamps (ms)
        Presenter->>Client: Finish Rehearsal
        Client->>API: POST /slides/{id}/rehearse (Audio + Timestamps)
        API->>Groq: Evaluate per-slide coverage and speech timing
        API-->>Client: Rehearsal Diagnostics (Pacing, Overtime Alerts)
    end
```

</details>

---

### 3. Target Audience Strategy Matrix

The presentation coaching engine dynamically reconfigures its evaluation criteria depending on the chosen target audience:

<p align="center">
  <img src="assets/3%20Target%20Audience%20Strategy%20Matrix.png" alt="Target Audience Strategy Matrix" width="100%" />
</p>

<details>
<summary><b>View Audience Decision Tree (Mermaid Definition)</b></summary>

```mermaid
graph LR
    Input[Target Audience Selection] --> Mode{Audience Type}

    Mode -->|Hackathon Judges| H[Pillars: Problem • Architecture • Prototype • Roadmap<br/>Focus: Tech stack, UART/SPI drivers, benchmarks, live demo failover<br/>Rule: Do NOT penalize for lack of equity/funding asks]
    Mode -->|Investors / VCs| I[Pillars: Problem • Solution • Traction • Ask<br/>Focus: TAM/SAM, unit economics, revenue, market moat<br/>Rule: Mandatory Ask Slide check]
    Mode -->|Class / Academic| C[Pillars: Context • Methodology • Results • Conclusion<br/>Focus: Experimental validity, comparative baselines, future work<br/>Rule: Scientific rigor and clear methodology]
    Mode -->|Potential Clients| CL[Pillars: Pain Point • Value Prop • Proof • Next Steps<br/>Focus: ROI, reliability, security guarantees, onboarding ease<br/>Rule: Clear business call-to-action]
    Mode -->|General Audience| G[Pillars: Hook • Core Story • Real-World Impact • Takeaway<br/>Focus: Relatable analogies, visual clarity, narrative tension<br/>Rule: Minimize jargon cognitive load]
```

</details>

---

## ⚡ Key Technical Optimizations

### ML & Audio Signal Processing Optimizations
* **Memory-Mapped FFmpeg Streaming**: Rather than saving temporary audio files on disk and incurring storage I/O latency, audio streams are piped directly from HTTP payload buffers into an FFmpeg subprocess via `stdin` and read out as raw 16kHz 16-bit PCM via `stdout`.
* **Zero-Hallucination Silence Guard**: Audio bursts shorter than 1.0s or with RMS amplitude below $-45\text{ dBFS}$ are caught prior to calling Groq LLM APIs. This saves unnecessary token consumption and prevents LLM hallucination on empty room noise.
* **Vectorized NumPy DSP**: Pitch tracking ($F_0$) utilizes normalized autocorrelation on windowed audio slices, executing standard deviation and monotone classification in sub-$100\text{ms}$ latency.
* **Deterministic Structured JSON**: Groq prompts enforce rigid Pydantic JSON schemas with temperature $= 0.15$, guaranteeing that all slide coaching payloads parse reliably without regex scrapers.

### Frontend & Mobile UX Optimizations
* **Flutter Impeller Engine**: Utilizes Impeller's ahead-of-time (AOT) compiled shaders on OpenGLES / Vulkan backends, eliminating shader compilation stutter during intensive chart zooming and carousel swiping.
* **Debounced State Patching**: User edits to talking points and scripts are debounced with an $800\text{ms}$ timer in `SlideCoachProvider`, eliminating network thrashing while guaranteeing auto-save persistence.
* **Zero-Truncation Responsive Cue Cards**: Replaced rigid single-line inputs with flexible multiline `TextFormField` containers (`minLines: 1`, `maxLines: 5`) with `TextInputType.multiline`, accommodating detailed speech cues without clipping text on compact screens.
* **Clean Chart Interpolation**: Implemented custom tick suppression math in `fl_chart` to eliminate fractional day interpolations and prevent duplicate dates on progress trend curves.
* **Scoped Storage MediaStore Synchronization**: On Android 11+ (API 30–36), programmatic file injection automatically broadcasts MediaStore insertion events so presentation PDFs appear immediately inside the system Storage Access Framework (SAF) picker.

### Data Layer & Reliability Optimizations
* **Async MongoDB Pipeline**: Integrated `motor` / `pymongo` with indexed user queries (`user_id`, `created_at`), allowing sub-millisecond retrieval of historical sessions and analytics summaries.
* **Dual-State Resilience**: If MongoDB or internet access is unavailable, the mobile app smoothly degrades to local SQLite storage and offline demo repositories without throwing unhandled exceptions.

---

## 📁 Project Directory Structure

```
pitch-coach/
├── 📄 README.md                            # Comprehensive platform documentation
├── 📄 pubspec.yaml                         # Flutter dependencies and assets
├── 📄 analysis_options.yaml                # Dart lint rules and static analysis
│
├── 📂 backend/                             # FastAPI High-Performance Server
│   ├── 🐍 main.py                          # Application factory, CORS, and router registry
│   ├── 🐍 config.py                        # Pydantic environment configuration
│   ├── 🐍 models.py                        # MongoDB document schemas and helpers
│   ├── 🐍 schemas.py                       # Request/Response validation models
│   ├── 🐍 quota.py                         # Daily evaluation usage limiter
│   ├── 📄 requirements.txt                 # Python dependencies manifest
│   ├── 📜 start.bat                        # Windows dev server launcher
│   │
│   ├── 📂 audio_analysis/                  # Acoustic DSP engine
│   │   └── 🐍 vocal_delivery.py            # F0 pitch variance, energy curve & monotone detector
│   │
│   ├── 📂 slides/                          # Multimodal Slide Coach engine
│   │   ├── 🐍 pipeline.py                  # PyMuPDF rendering, audience strategies & Groq synthesis
│   │   ├── 🐍 router.py                    # Slide upload, patching, rehearsal & Q&A endpoints
│   │   ├── 🐍 schemas.py                   # Pydantic schemas for slide coaching models
│   │   └── 🐍 store.py                     # Slide deck database access layer
│   │
│   ├── 📂 sessions/                        # Speech practice studio
│   │   ├── 🐍 pipeline.py                  # Audio ingestion, silence guard & Groq Whisper/LLM
│   │   ├── 🐍 router.py                    # Session recording endpoints
│   │   └── 🐍 coach_agent.py               # AI speech evaluation agent
│   │
│   ├── 📂 auth/                            # Authentication & JWT issuance
│   ├── 📂 users/                           # User profiles & speaking goals
│   ├── 📂 stats/                           # Aggregated metrics & trend analytics
│   ├── 📂 achievements/                    # Streaks, badges, and milestones
│   └── 📂 tests/                           # Pytest unit & integration test suites
│
└── 📂 frontend/                            # Flutter Mobile Application
    ├── 📂 lib/
    │   ├── 📱 main.dart                    # App bootstrap, theme setup & route injection
    │   │
    │   ├── 📂 core/                        # Shared infrastructure
    │   │   ├── 📂 models/                  # Typed Dart models (SlideCoach, Session, Stats)
    │   │   ├── 📂 providers/               # State providers (SlideCoach, User, Theme, Stats)
    │   │   ├── 📂 repositories/            # REST API clients & offline mock repositories
    │   │   ├── 📂 router/                  # GoRouter configuration & route definitions
    │   │   ├── 📂 services/                # Audio recording, playback & secure storage
    │   │   ├── 📂 theme/                   # AppColors, typography tokens & Material 3 themes
    │   │   └── 📂 widgets/                 # Reusable UI widgets & custom painters
    │   │
    │   └── 📂 features/                    # Feature modules
    │       ├── 📂 slide_coach/             # Deck upload, deck review, live rehearsal & Q&A
    │       ├── 📂 interview/               # Audio practice studio with teleprompter
    │       ├── 📂 results/                 # Post-session evaluation & audio playback
    │       ├── 📂 progress/                # fl_chart analytics & growth radar
    │       ├── 📂 history/                 # Session archives & search filter
    │       ├── 📂 learn/                   # Video lessons & speaking curriculum
    │       ├── 📂 home/                    # Central hub, streak tracker & quick practice
    │       ├── 📂 profile/                 # Profile settings & AI strictness configuration
    │       └── 📂 auth/                    # Login, registration, and onboarding
    │
    └── 📂 test/                            # Flutter widget & unit test suites
```

---

## 🔌 API Endpoints Reference

Interactive Swagger/OpenAPI documentation is available at `http://localhost:8000/docs`.

### 🎯 Slide Coach AI Endpoints
| Method | Endpoint | Description |
|:---:|:---|:---|
| `POST` | `/slides/upload` | Upload PDF/PPTX deck with target audience, goal & time limit |
| `GET` | `/slides/{deck_id}` | Retrieve complete deck coaching analysis, story arc & slides |
| `GET` | `/slides/{deck_id}/status` | Poll deck processing stage and progress percentage |
| `PATCH`| `/slides/{deck_id}/slides/{slide_num}` | Live auto-save user edits to talking points, scripts, or duration |
| `GET` | `/slides/{deck_id}/slides/{slide_num}/image` | Stream high-resolution rendered PNG image of a slide |
| `POST` | `/slides/{deck_id}/rehearse` | Evaluate live rehearsal audio aligned with slide timestamps |
| `GET` | `/slides/{deck_id}/qa/questions` | Generate audience-specific cross-examination questions |
| `POST` | `/slides/{deck_id}/qa/evaluate` | Evaluate spoken user answer to an audience question |

### 🎙️ Speech Studio & Core Endpoints
| Method | Endpoint | Description |
|:---:|:---|:---|
| `POST` | `/sessions/upload` | Ingest audio file, run DSP pipeline, transcribe, and score |
| `GET` | `/sessions/` | Paginated history of completed practice attempts |
| `GET` | `/sessions/{session_id}` | Detailed session analysis with transcript and metric breakdown |
| `GET` | `/stats/summary` | Total sessions, average confidence, and best score cards |
| `GET` | `/stats/trends` | Historical timeline metrics formatted for charting |
| `GET` | `/achievements/` | Active streak, badge progression, and unlocked tiers |
| `POST` | `/auth/register` | Register new account with email and password |
| `POST` | `/auth/login` | Authenticate user credentials and return Bearer JWT |

---

## 🚀 Quickstart & Setup Guide

### 1. Backend Setup

#### Prerequisites
* **Python 3.10+** (Python 3.12 recommended)
* **FFmpeg**: Required for audio transcoding:
  * Windows: `winget install Gyan.FFmpeg` or `choco install ffmpeg`
  * macOS: `brew install ffmpeg`
  * Linux: `sudo apt-get install ffmpeg`

```powershell
# 1. Navigate to backend directory
cd backend

# 2. Create and activate virtual environment
python -m venv venv
.\venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment variables
copy .env.example .env
# Edit .env and supply your GROQ_API_KEY and MONGODB_URL:
# GROQ_API_KEY=gsk_your_key_here
# MONGODB_URL=mongodb+srv://user:pass@cluster.mongodb.net/pitchcoach

# 5. Launch development server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

### 2. Flutter App Setup

#### Prerequisites
* **Flutter SDK 3.10.0+**
* Android Studio / VS Code with Flutter extension
* Android Emulator (API 30+) or physical device

```powershell
# 1. Navigate to frontend directory
cd frontend

# 2. Install Dart packages
flutter pub get

# 3. Verify toolchain health
flutter doctor
```

---

### 3. Device Connection Modes

Select the appropriate launch argument based on your deployment environment:

#### 📱 Android Emulator
The Android emulator accesses host `localhost` via the loopback bridge `10.0.2.2`:
```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### 📲 Physical Device (Wi-Fi)
Find your workstation's LAN IP via `ipconfig` (e.g. `192.168.1.100`):
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

#### 💻 Desktop / Web
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

#### 🚀 Offline / Guest Mode
Launch without parameters. Pitch Coach automatically detects the environment and switches to offline mock mode:
```powershell
flutter run
```

---

## 🎨 Design Tokens & Theming

Pitch Coach implements a curated HSL color palette engineered for high contrast and reduced visual fatigue:

| Token | Hex Value | Role |
| :--- | :---: | :--- |
| `AppColors.scaffoldDark` | `#0B0C10` | Dark theme canvas background |
| `AppColors.cardDark` | `#15161E` | Elevated dark container surface |
| `AppColors.primaryPurple` | `#6C5CE7` | Primary brand accent & active state |
| `AppColors.primaryPurpleLight` | `#8B5CF6` | Gradient highlight and badge tints |
| `AppColors.auroraCyan` | `#00D2D3` | Secondary metrics, pacing cues & timing badges |
| `AppColors.successGreen` | `#10B981` | Positive feedback, high scores & auto-save pills |
| `AppColors.warningAmber` | `#F5A623` | Pacing alerts, slide critique & filler warnings |
| `AppColors.dangerRed` | `#E85C5C` | Missing pitch elements & recording stop button |

---

## 🧪 Testing & Quality Assurance

### Backend Test Suite (Pytest)
```powershell
cd backend
.\venv\Scripts\pytest tests/test_slide_coach_upgrades.py -v
```

### Frontend Analyzer & Widget Tests
```powershell
cd frontend
# Static analysis
dart analyze

# Run all slide coach & UI tests
flutter test test/features/slide_coach/slide_coach_upgrades_test.dart
```

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.

<p align="center">
  Built with ❤️ for presenters, startup founders, and public speakers worldwide.
</p>
