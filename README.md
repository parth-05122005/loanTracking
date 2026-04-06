# 🌱 EcoLedger: Smart Loan Tracking System

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

> **A secure, real-time dashboard for transparent micro-loan disbursal and expense tracking.**

---

## 📖 Overview

When agricultural or micro-loans are distributed, tracking whether the funds were actually spent on approved items (like seeds or fertilizers) is a massive operational challenge.

**EcoLedger** solves this by providing a dedicated digital ledger for beneficiaries.

The platform allows users to:
- Log expenses
- Upload physical receipts
- Geographically tag transactions

This ensures **complete transparency and accountability** for the funds allocated to them.

---

## ✨ Key Features

- **⚡ Real-Time Dashboard Sync**  
  The Flutter client utilizes WebSockets (`StreamBuilder`) to instantly update:
  - User balances
  - Transaction lists
  - Visual pie charts

- **📍 Geo-Tagged Audit Trail**  
  Manual receipt uploads utilize native device GPS to bind precise geographic coordinates (`latitude/longitude`) to each transaction.

- **📸 Offloaded Image Hosting**  
  Physical receipts are captured via camera and securely hosted on **Cloudinary CDN** to keep the primary NoSQL database lightweight and performant.

- **🔐 Secure Authentication**  
  Seamless and secure onboarding using **Firebase Google Sign-In**.

---

## 🛠️ Tech Stack

### Frontend (Mobile App)
- **Framework:** Flutter (Dart)
- **Architecture:** MVC Pattern
- **State Management:** Reactive Streams (`StreamBuilder`, `ValueNotifier`)
- **Key Packages:**
  - `geolocator`
  - `image_picker`
  - `percent_indicator`
  - `google_fonts`

### Backend (Cloud & Database)
- **Database:** Firebase Cloud Firestore (NoSQL)
- **Authentication:** Firebase Auth
- **Media Storage:** Cloudinary REST API

---

## ⚙️ System Architecture

1. **Transaction Entry**  
   The user inputs expense details and captures a receipt image.

2. **Media Processing**  
   The app uploads the image to Cloudinary via REST API and receives a secure URL.

3. **Location Tagging**  
   The app fetches the current GPS coordinates using native device hardware.

4. **Data Sync**  
   The app pushes a consolidated JSON payload including:
   - image URL
   - coordinates
   - expense details  
   to Cloud Firestore.

5. **Real-Time Update**  
   Firestore pushes the updated ledger back to the client, dynamically recalculating the available loan balance.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.0+)
- A Firebase Project (with Firestore and Authentication enabled)
- A Cloudinary Account (Unsigned Upload Preset configured)

---

## 📦 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/EcoLedger.git
cd EcoLedger
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Update API Keys

Navigate to:

```text
lib/services/cloudinary_service.dart
```

Add your:
- `cloudName`
- `uploadPreset`

Also ensure your Firebase config files are added:

- `google-services.json` → Android
- `GoogleService-Info.plist` → iOS

### 4. Run the App
```bash
flutter run
```

---

## 🔮 Future Scope: IoT Hardware Integration

To further secure the disbursal process and eliminate the possibility of mobile-device spoofing, the next phase of **EcoLedger** involves integrating physical hardware edge nodes.

### 🧠 Planned Enhancements

#### IoT Point-of-Sale (PoS)
Deploy **ESP32 microcontrollers** equipped with **RFID RC522 scanners** at registered vendor locations.

#### Smart Card Disbursal
Beneficiaries will be issued **offline RFID Smart Cards** instead of relying solely on the mobile app.

#### Hardware-Locked Transactions
Transactions will only process via hardware interrupts at the vendor’s physical node.

The node will:
- Construct JSON payloads
- Make secure HTTP POST requests
- Sync directly with **Google Cloud Firestore REST API**

This will significantly improve **security, fraud prevention, and real-world traceability**.