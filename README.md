# SnapSpend 🧾✨

SnapSpend is a smart, privacy-first personal finance application built with Flutter. It helps you track your expenses by simply scanning your physical receipts. Powered by **Tesseract OCR** and **Llama C++ (Offline AI)**, SnapSpend extracts key information from your receipts securely on your device—no cloud processing required!

## 🌟 Key Features

* **Offline AI Extraction**: Uses a local Llama model (Qwen2.5 1.5B via `flutter_llama_cpp`) to intelligently parse receipt text into structured JSON data (Merchant, Amount, Date, Category). Your data never leaves your phone!
* **Fast Tesseract OCR**: Employs Tesseract OCR to accurately convert receipt images into processable text.
* **Smart Dashboard**: A beautiful, modern "Glassmorphism" UI that provides:
  * Dynamic weekly spending patterns.
  * Recent transaction previews.
  * Total expenses summary.
* **Transaction History**: View all your scanned receipts grouped beautifully by date.
* **On-Device Database**: Uses `sqflite` for fast, private, and persistent local storage.

## 📸 Screenshots
*(Add your app screenshots here!)*

## 🛠️ Technology Stack

* **Frontend**: Flutter & Dart (Cross-platform capability)
* **Local Database**: SQLite (`sqflite`)
* **OCR Engine**: `flutter_tesseract_ocr`
* **Local LLM**: `flutter_llama_cpp` (Running GGUF models directly on device)
* **Image Selection**: `image_picker`
* **UI/UX**: Custom Glassmorphism design system using Google Fonts (`Manrope`, `Inter`).

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (Latest stable version)
* Android Studio or VS Code
* An Android device or emulator (Physical device recommended for AI & Camera features, specifically `arm64-v8a`).

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd snapspend
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app!**
   ```bash
   flutter run
   ```

### 📦 Building for Release

Because this app embeds heavy C++ native libraries for the AI model (`libllama.so`), **you must split the APK by architecture** to keep the app size optimized:

```bash
flutter build apk --split-per-abi
```

*Locate your release APK at: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`*

## 🧠 How the AI Works

1. **Image Capture**: The user picks a receipt image from the gallery (or takes a photo).
2. **Preprocessing & OCR**: The image is preprocessed and read by `Tesseract OCR` to extract raw text.
3. **Local Text Generation**: The text is passed into a highly quantized Llama model format (`.gguf`) running entirely within a separate isolate thread so the main UI never freezes.
4. **Greedy JSON Extraction**: The model has been strictly prompted with greedy deterministic sampling to output *only* a valid JSON structure representing your receipt's metadata.
5. **Storage**: Data is parsed and saved securely to your local SQLite Database.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📝 License

This project is open-source and available under the [MIT License](LICENSE).
Beta
0 / 0
used queries
1
