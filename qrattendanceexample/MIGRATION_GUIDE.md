# Migration Guide: Flutter QR Attendance App to React/Next.js & React Native

## Table of Contents
1. [Project Overview](#project-overview)
2. [Current Architecture](#current-architecture)
3. [Target Architecture](#target-architecture)
4. [Technology Stack Mapping](#technology-stack-mapping)
5. [Migration Strategy](#migration-strategy)
6. [Step-by-Step Migration Plan](#step-by-step-migration-plan)
7. [Code Migration Examples](#code-migration-examples)
8. [Database Considerations](#database-considerations)
9. [Backend Migration Options](#backend-migration-options)
10. [Testing Strategy](#testing-strategy)
11. [Deployment Considerations](#deployment-considerations)
12. [Common Challenges & Solutions](#common-challenges--solutions)

---

## Project Overview

### Current Application
A QR and RFID-based attendance tracking system with the following features:
- **User Roles**: Student, Admin, Officer
- **QR Code Generation & Scanning**: Event-specific QR codes for attendance
- **RFID/NFC Support**: Read and write RFID/NFC tags for attendance tracking
- **Event Management**: Create, edit, delete events with time-based tracking
- **Attendance Tracking**: Time in/out system with status detection (present, late, absent, left early)
- **Survey System**: Event-based surveys with responses and statistics
- **Offline Support**: QR scanning and data sync capabilities
- **Analytics**: Event analytics and attendance statistics
- **Calendar Integration**: Calendar view for events

### Technology Stack (Current)
- **Frontend**: Flutter/Dart (Mobile)
- **Backend**: PHP 7.4+ with PDO
- **Database**: MySQL (MariaDB)
- **State Management**: Provider pattern
- **Storage**: SharedPreferences, Flutter Secure Storage
- **QR Libraries**: qr_flutter, mobile_scanner
- **NFC/RFID**: nfc_manager package
- **Networking**: http package

---

## Current Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Mobile Only)  │
├─────────────────┤
│ - Student UI    │
│ - Admin UI      │
│ - Officer UI    │
└────────┬────────┘
         │ HTTP/REST
         ▼
┌─────────────────┐
│  PHP Backend    │
│  (XAMPP)        │
├─────────────────┤
│ - REST API      │
│ - Authentication│
│ - Business Logic│
└────────┬────────┘
         │ PDO
         ▼
┌─────────────────┐
│   MySQL DB      │
└─────────────────┘
```

### Key Components
- **Models**: User, Event, Attendance, Survey
- **Providers**: AuthProvider, EventProvider, AttendanceProvider, SurveyProvider
- **Screens**: Authentication, Dashboards, QR Scanner, RFID Scanner, Event Management, Surveys
- **API Endpoints**: `/api/login.php`, `/api/events/`, `/api/attendance/`, `/api/surveys/`

---

## Target Architecture

### Option 1: Full Next.js + React Native (Recommended)
```
┌──────────────────────┐     ┌──────────────────────┐
│   Next.js Web App    │     │  React Native App    │
│   (Admin Dashboard)  │     │  (Mobile - iOS/Android│
├──────────────────────┤     ├──────────────────────┤
│ - SSR/SSG            │     │ - Native Components  │
│ - Server Components  │     │ - QR Scanner         │
│ - API Routes         │     │ - Camera Access      │
└──────────┬───────────┘     └──────────┬───────────┘
           │                            │
           └────────────┬───────────────┘
                        │ HTTP/REST/GraphQL
                        ▼
           ┌──────────────────────────┐
           │   Next.js API Routes     │
           │   or Node.js Backend     │
           ├──────────────────────────┤
           │ - Authentication         │
           │ - Business Logic         │
           │ - File Upload            │
           └──────────┬───────────────┘
                      │
                      ▼
           ┌──────────────────────────┐
           │      MySQL Database      │
           └──────────────────────────┘
```

### Option 2: Separate Backend (Alternative)
```
┌──────────────────┐     ┌──────────────────┐
│  Next.js Frontend│     │ React Native App │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         └──────────┬─────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │  Node.js/Express API │
         │  or NestJS Backend   │
         └──────────┬───────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │    MySQL Database    │
         └──────────────────────┘
```

---

## Technology Stack Mapping

### Frontend Migration

| Flutter/Dart | React/Next.js | React Native | Notes |
|--------------|---------------|--------------|-------|
| `Provider` | Context API / Zustand / Redux Toolkit | Context API / Zustand / Redux Toolkit | State management |
| `http` package | `fetch` / `axios` / `SWR` / `TanStack Query` | `fetch` / `axios` / `React Query` | HTTP client |
| `SharedPreferences` | `localStorage` / Cookies | `@react-native-async-storage/async-storage` | Local storage |
| `flutter_secure_storage` | `js-cookie` / `next-auth` | `react-native-keychain` / `expo-secure-store` | Secure storage |
| `qr_flutter` | `qrcode.react` / `react-qr-code` | `react-native-qrcode-svg` | QR generation |
| `mobile_scanner` | `html5-qrcode` / `@zxing/library` | `react-native-camera` / `expo-camera` + `expo-barcode-scanner` | QR scanning |
| `intl` | `date-fns` / `dayjs` | `date-fns` / `dayjs` | Date formatting |
| `image_picker` | `<input type="file">` / `react-dropzone` | `react-native-image-picker` / `expo-image-picker` | Image picking |
| `permission_handler` | Browser APIs | `react-native-permissions` / `expo-permissions` | Permissions |
| `connectivity_plus` | Browser APIs | `@react-native-netinfo/netinfo` | Network status |
| `nfc_manager` | Web NFC API (limited browser support) | `react-native-nfc-manager` / `react-native-nfc` | RFID/NFC reading & writing |
| Material Design | Material-UI (MUI) / Chakra UI / Tailwind CSS | React Native Paper / NativeBase | UI components |

### Backend Migration

| PHP | Node.js/Next.js Alternative | Notes |
|-----|----------------------------|-------|
| PDO | `mysql2` / `prisma` / `typeorm` / `drizzle-orm` | Database ORM |
| `password_hash()` | `bcrypt` / `argon2` | Password hashing |
| `json_encode()` | Native JSON / `fast-json-stringify` | JSON handling |
| `$_POST`, `$_GET` | `req.body`, `req.query` (Express) | Request handling |
| Session | JWT / `next-auth` / Passport.js | Authentication |
| File uploads | `multer` / `formidable` | File handling |

---

## Migration Strategy

### Phase 1: Foundation Setup (Week 1-2)
1. Set up Next.js project structure
2. Set up React Native project (Expo or bare)
3. Create shared code repository/structure
4. Set up TypeScript configuration
5. Set up API client utilities
6. Database schema review and migration scripts

### Phase 2: Backend Migration (Week 3-5)
1. Migrate PHP APIs to Next.js API routes or Node.js
2. Implement authentication (JWT/NextAuth)
3. Migrate database models to TypeScript interfaces
4. Set up database connection layer
5. Test API endpoints

### Phase 3: Core Features - Web (Week 6-8)
1. Authentication (Login/Register)
2. User models and context
3. Event management (CRUD)
4. Admin dashboard
5. Basic UI components

### Phase 4: Core Features - Mobile (Week 9-11)
1. Authentication screens
2. QR code generation
3. QR code scanning
4. Student dashboard
5. Attendance tracking

### Phase 5: Advanced Features (Week 12-14)
1. Survey system
2. Analytics and reporting
3. Offline support
4. Calendar integration
5. Image uploads

### Phase 6: Testing & Optimization (Week 15-16)
1. Unit tests
2. Integration tests
3. E2E tests
4. Performance optimization
5. Security audit

### Phase 7: Deployment (Week 17-18)
1. Production build setup
2. Database migration
3. Deployment configuration
4. Monitoring setup
5. Documentation

---

## Step-by-Step Migration Plan

### Step 1: Project Initialization

#### Next.js Setup
```bash
# Create Next.js app with TypeScript
npx create-next-app@latest qr-attendance-web --typescript --tailwind --app
cd qr-attendance-web

# Install dependencies
npm install zustand axios date-fns qrcode.react
npm install @types/node @types/react @types/react-dom
npm install -D @types/qrcode.react
```

#### React Native Setup (Expo)
```bash
# Create Expo app
npx create-expo-app qr-attendance-mobile --template expo-template-blank-typescript
cd qr-attendance-mobile

# Install dependencies
npx expo install expo-camera expo-barcode-scanner expo-secure-store @react-native-async-storage/async-storage
npm install zustand axios date-fns react-native-qrcode-svg
npm install @react-native-netinfo/netinfo
```

#### React Native Setup (Bare - Alternative)
```bash
# Create React Native app
npx react-native init QRAttendanceMobile --template react-native-template-typescript
cd QRAttendanceMobile

# Install dependencies
npm install @react-native-async-storage/async-storage react-native-keychain
npm install react-native-camera react-native-qrcode-svg
npm install zustand axios date-fns
npm install @react-native-netinfo/netinfo
```

### Step 2: Project Structure

#### Next.js Structure
```
qr-attendance-web/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── register/
│   ├── (dashboard)/
│   │   ├── admin/
│   │   ├── student/
│   │   └── officer/
│   ├── api/
│   │   ├── auth/
│   │   ├── events/
│   │   ├── attendance/
│   │   └── surveys/
│   └── layout.tsx
├── components/
│   ├── ui/
│   ├── forms/
│   └── qr/
├── lib/
│   ├── api/
│   ├── hooks/
│   ├── stores/
│   ├── types/
│   └── utils/
├── public/
└── package.json
```

#### React Native Structure
```
qr-attendance-mobile/
├── src/
│   ├── screens/
│   │   ├── auth/
│   │   ├── student/
│   │   ├── admin/
│   │   └── officer/
│   ├── components/
│   │   ├── ui/
│   │   └── qr/
│   ├── navigation/
│   ├── stores/
│   ├── services/
│   │   ├── api.ts
│   │   └── storage.ts
│   ├── types/
│   └── utils/
├── app.json
└── package.json
```

### Step 3: Shared Types Definition

Create `types/index.ts` (shared between web and mobile):
```typescript
export enum UserRole {
  STUDENT = 'student',
  ADMIN = 'admin',
  OFFICER = 'officer',
}

export interface User {
  id: string;
  name: string;
  email: string;
  studentId: string;
  yearLevel: string;
  department: string;
  course: string;
  gender: string;
  birthdate?: string;
  role: UserRole;
  createdAt: string;
  updatedAt: string;
}

export interface Event {
  id: string;
  title: string;
  description: string;
  startTime: string;
  endTime: string;
  location: string;
  organizer?: string;
  createdBy: string;
  createdAt: string;
  updatedAt?: string;
  isActive: boolean;
  qrCode?: string;
  thumbnail?: string;
  targetDepartment?: string;
  targetCourse?: string;
  targetYearLevel?: string;
}

export interface Attendance {
  id: string;
  eventId: string;
  userId: string;
  studentId: string;
  studentName: string;
  checkInTime?: string;
  checkOutTime?: string;
  status: 'present' | 'late' | 'absent' | 'left_early';
  notes?: string;
  createdAt: string;
}

export interface Survey {
  id: string;
  eventId: string;
  title: string;
  description: string;
  questions: SurveyQuestion[];
  createdAt: string;
}

export interface SurveyQuestion {
  id: string;
  type: 'text' | 'multiple_choice' | 'rating';
  question: string;
  options?: string[];
  required: boolean;
}
```

### Step 4: API Client Setup

#### Web: `lib/api/client.ts`
```typescript
import axios from 'axios';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000/api';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for auth token
apiClient.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Handle unauthorized
      if (typeof window !== 'undefined') {
        localStorage.removeItem('auth_token');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);
```

#### Mobile: `src/services/api.ts`
```typescript
import axios from 'axios';
import * as SecureStore from 'expo-secure-store';

const API_BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL || 'http://localhost:3000/api';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for auth token
apiClient.interceptors.request.use(async (config) => {
  const token = await SecureStore.getItemAsync('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      await SecureStore.deleteItemAsync('auth_token');
      // Navigate to login (handle in your navigation)
    }
    return Promise.reject(error);
  }
);
```

---

## Code Migration Examples

### Example 1: User Model Migration

#### Flutter (Original)
```dart
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  User({required this.id, required this.name, required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
    };
  }
}
```

#### TypeScript (Migrated)
```typescript
// types/user.ts
export interface User {
  id: string;
  name: string;
  email: string;
  studentId: string;
  yearLevel: string;
  department: string;
  course: string;
  gender: string;
  birthdate?: string;
  role: UserRole;
  createdAt: string;
  updatedAt: string;
}

export function userFromJson(json: any): User {
  return {
    id: String(json.id),
    name: json.name,
    email: json.email,
    studentId: json.studentId || json.student_id || '',
    yearLevel: json.yearLevel || json.year_level || '',
    department: json.department || '',
    course: json.course || '',
    gender: json.gender || '',
    birthdate: json.birthdate || undefined,
    role: json.role as UserRole,
    createdAt: json.createdAt || json.created_at,
    updatedAt: json.updatedAt || json.updated_at || json.createdAt,
  };
}
```

### Example 2: Authentication Provider Migration

#### Flutter (Original)
```dart
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _user = User.fromJson(data['user']);
          await _saveUserToStorage(_user!);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
```

#### TypeScript with Zustand (Migrated)
```typescript
// stores/authStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { User, userFromJson } from '../types';
import { apiClient } from '../services/api';

interface AuthState {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => void;
  loadUser: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isLoading: false,
      isAuthenticated: false,

      login: async (email: string, password: string) => {
        set({ isLoading: true });
        try {
          const response = await apiClient.post('/auth/login', {
            email,
            password,
          });

          if (response.data.success) {
            const user = userFromJson(response.data.user);
            const token = response.data.token; // If using JWT

            // Store token
            if (typeof window !== 'undefined') {
              localStorage.setItem('auth_token', token);
            }

            set({
              user,
              isAuthenticated: true,
              isLoading: false,
            });
            return true;
          }
          set({ isLoading: false });
          return false;
        } catch (error) {
          set({ isLoading: false });
          return false;
        }
      },

      logout: () => {
        if (typeof window !== 'undefined') {
          localStorage.removeItem('auth_token');
        }
        set({ user: null, isAuthenticated: false });
      },

      loadUser: async () => {
        // Load user from token or storage
        const token = typeof window !== 'undefined' 
          ? localStorage.getItem('auth_token') 
          : null;
        
        if (token) {
          try {
            const response = await apiClient.get('/auth/me');
            const user = userFromJson(response.data.user);
            set({ user, isAuthenticated: true });
          } catch (error) {
            set({ user: null, isAuthenticated: false });
          }
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ user: state.user }),
    }
  )
);
```

### Example 3: QR Code Generation

#### Flutter (Original)
```dart
import 'package:qr_flutter/qr_flutter.dart';

Widget buildQRCode(String eventId, String studentId) {
  final qrData = jsonEncode({
    'eventId': eventId,
    'studentId': studentId,
  });

  return QrImageView(
    data: qrData,
    version: QrVersions.auto,
    size: 200.0,
  );
}
```

#### React/Next.js (Migrated)
```typescript
// components/qr/QRCodeDisplay.tsx
import { QRCodeSVG } from 'qrcode.react';

interface QRCodeDisplayProps {
  eventId: string;
  studentId: string;
  size?: number;
}

export function QRCodeDisplay({ eventId, studentId, size = 200 }: QRCodeDisplayProps) {
  const qrData = JSON.stringify({
    eventId,
    studentId,
  });

  return (
    <QRCodeSVG
      value={qrData}
      size={size}
      level="H"
      includeMargin={true}
    />
  );
}
```

#### React Native (Migrated)
```typescript
// components/qr/QRCodeDisplay.tsx
import QRCode from 'react-native-qrcode-svg';

interface QRCodeDisplayProps {
  eventId: string;
  studentId: string;
  size?: number;
}

export function QRCodeDisplay({ eventId, studentId, size = 200 }: QRCodeDisplayProps) {
  const qrData = JSON.stringify({
    eventId,
    studentId,
  });

  return (
    <QRCode
      value={qrData}
      size={size}
      color="black"
      backgroundColor="white"
    />
  );
}
```

### Example 4: QR Code Scanning

#### Flutter (Original)
```dart
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  void _onDetect(BarcodeCapture capture) {
    final String? code = capture.barcodes.first.rawValue;
    if (code != null) {
      // Process QR code
      _processQRCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect,
      ),
    );
  }
}
```

#### React/Next.js (Migrated - Web)
```typescript
// components/qr/QRScanner.tsx
'use client';

import { Html5Qrcode } from 'html5-qrcode';
import { useEffect, useRef } from 'react';

interface QRScannerProps {
  onScanSuccess: (decodedText: string) => void;
  onScanFailure?: (error: string) => void;
}

export function QRScanner({ onScanSuccess, onScanFailure }: QRScannerProps) {
  const html5QrCodeRef = useRef<Html5Qrcode | null>(null);

  useEffect(() => {
    const html5QrCode = new Html5Qrcode('qr-reader');
    html5QrCodeRef.current = html5QrCode;

    html5QrCode.start(
      { facingMode: 'environment' },
      {
        fps: 10,
        qrbox: { width: 250, height: 250 },
      },
      onScanSuccess,
      onScanFailure || (() => {})
    );

    return () => {
      if (html5QrCodeRef.current?.isScanning) {
        html5QrCodeRef.current.stop().catch(() => {});
      }
    };
  }, []);

  return <div id="qr-reader" style={{ width: '100%' }} />;
}
```

#### React Native (Migrated)
```typescript
// components/qr/QRScanner.tsx
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useState, useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import { BarCodeScanner } from 'expo-barcode-scanner';

interface QRScannerProps {
  onScanSuccess: (data: string) => void;
}

export function QRScanner({ onScanSuccess }: QRScannerProps) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);

  useEffect(() => {
    if (!permission?.granted) {
      requestPermission();
    }
  }, []);

  const handleBarCodeScanned = ({ data }: { data: string }) => {
    if (!scanned) {
      setScanned(true);
      onScanSuccess(data);
      setTimeout(() => setScanned(false), 2000);
    }
  };

  if (!permission?.granted) {
    return <View />; // Request permission UI
  }

  return (
    <CameraView
      style={StyleSheet.absoluteFillObject}
      facing="back"
      onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
      barcodeScannerSettings={{
        barcodeTypes: ['qr'],
      }}
    />
  );
}
```

### Example 5: RFID/NFC Scanner Migration

The app includes comprehensive RFID/NFC functionality for both reading tags (for attendance) and writing data to tags. This is primarily a mobile feature as web browsers have very limited NFC support.

#### Flutter (Original)
```dart
import 'package:nfc_manager/nfc_manager.dart';

class RFIDScannerScreen extends StatefulWidget {
  @override
  _RFIDScannerScreenState createState() => _RFIDScannerScreenState();
}

class _RFIDScannerScreenState extends State<RFIDScannerScreen> {
  bool _isScanning = false;
  bool _nfcAvailable = false;
  String _statusMessage = 'Tap to start scanning NFC/RFID tags';

  Future<void> _checkNFCAvailability() async {
    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      setState(() {
        _nfcAvailable = isAvailable;
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        _statusMessage = 'Error checking NFC availability: $e';
      });
    }
  }

  Future<void> _startNFCScan() async {
    if (!_nfcAvailable) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold device near NFC/RFID tag...';
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            String? tagData;
            
            // Try to read NDEF data
            if (tag.data.containsKey('ndef')) {
              final ndef = Ndef.from(tag.data['ndef']);
              if (ndef != null && ndef.cachedMessage != null) {
                final records = ndef.cachedMessage!.records;
                if (records.isNotEmpty) {
                  final record = records.first;
                  if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
                    tagData = String.fromCharCodes(record.payload);
                  }
                }
              }
            } else {
              // Get identifier from tag data
              final identifier = tag.data['nfca']?['identifier'] ?? 
                                tag.data['nfcb']?['identifier'];
              if (identifier != null) {
                tagData = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
              }
            }

            if (tagData != null) {
              await NfcManager.instance.stopSession();
              _processTagData(tagData);
            }
          } catch (e) {
            print('Error processing tag: $e');
          }
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error starting NFC scan: $e';
      });
    }
  }

  Future<void> _writeToTag(String studentId, String eventId) async {
    if (!_nfcAvailable) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold device near RFID tag to write...';
    });

    try {
      final dataToWrite = jsonEncode({
        'studentId': studentId,
        'eventId': eventId,
      });
      final bytes = utf8.encode(dataToWrite);
      final base64Data = base64Encode(bytes);

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag.data['ndef']);
            if (ndef != null) {
              await ndef.write(NdefMessage([
                NdefRecord.createText(base64Data),
              ]));
              
              await NfcManager.instance.stopSession();
              setState(() {
                _isScanning = false;
                _statusMessage = 'Data written successfully!';
              });
            }
          } catch (e) {
            print('Error writing to tag: $e');
          }
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error writing to tag: $e';
      });
    }
  }
}
```

#### React Native (Migrated)

**Using react-native-nfc-manager:**

```typescript
// components/rfid/RFIDScanner.tsx
import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Alert } from 'react-native';
import NfcManager, { NfcTech, Ndef } from 'react-native-nfc-manager';
import { Buffer } from 'buffer';

interface RFIDScannerProps {
  onTagRead: (data: string) => void;
  writeMode?: boolean;
  dataToWrite?: string;
}

export function RFIDScanner({ onTagRead, writeMode = false, dataToWrite }: RFIDScannerProps) {
  const [isScanning, setIsScanning] = useState(false);
  const [nfcAvailable, setNfcAvailable] = useState(false);
  const [statusMessage, setStatusMessage] = useState('Tap to start scanning NFC/RFID tags');

  useEffect(() => {
    checkNFCAvailability();
    return () => {
      if (isScanning) {
        NfcManager.cancelTechnologyRequest().catch(() => {});
      }
    };
  }, []);

  const checkNFCAvailability = async () => {
    try {
      await NfcManager.start();
      const supported = await NfcManager.isSupported();
      setNfcAvailable(supported);
      if (!supported) {
        setStatusMessage('NFC is not available on this device');
      }
    } catch (error) {
      setNfcAvailable(false);
      setStatusMessage('Error checking NFC availability');
    }
  };

  const startScan = async () => {
    if (!nfcAvailable) {
      Alert.alert('NFC Not Available', 'NFC is not available on this device');
      return;
    }

    setIsScanning(true);
    setStatusMessage('Hold device near NFC/RFID tag...');

    try {
      await NfcManager.requestTechnology(NfcTech.Ndef);
      
      const tag = await NfcManager.getTag();
      if (tag) {
        let tagData: string | null = null;

        // Read NDEF message
        if (tag.ndefMessage && tag.ndefMessage.length > 0) {
          const ndefRecord = tag.ndefMessage[0];
          if (ndefRecord.payload) {
            // Skip the language code (first byte) for text records
            const payload = ndefRecord.payload;
            const textPayload = payload.slice(3); // Skip language code
            tagData = Buffer.from(textPayload).toString('utf-8');
          }
        } else {
          // Get tag ID as fallback
          if (tag.id) {
            tagData = Buffer.from(tag.id).toString('hex');
          }
        }

        if (tagData) {
          onTagRead(tagData);
        }
      }
    } catch (error: any) {
      if (error.message !== 'User cancelled') {
        setStatusMessage(`Error: ${error.message}`);
      }
    } finally {
      setIsScanning(false);
      await NfcManager.cancelTechnologyRequest();
    }
  };

  const startWrite = async () => {
    if (!nfcAvailable || !dataToWrite) {
      Alert.alert('Error', 'NFC not available or no data to write');
      return;
    }

    setIsScanning(true);
    setStatusMessage('Hold device near RFID tag to write...');

    try {
      await NfcManager.requestTechnology(NfcTech.Ndef);
      
      const tag = await NfcManager.getTag();
      if (tag) {
        // Encode data as base64
        const bytes = Buffer.from(dataToWrite, 'utf-8');
        const base64Data = bytes.toString('base64');

        // Create NDEF record
        const ndefRecord = Ndef.encodeMessage([
          Ndef.textRecord(base64Data),
        ]);

        if (ndefRecord) {
          await NfcManager.ndefHandler.writeNdefMessage(ndefRecord);
          setStatusMessage('Data written successfully!');
          Alert.alert('Success', 'Data written to RFID tag');
        }
      }
    } catch (error: any) {
      if (error.message !== 'User cancelled') {
        setStatusMessage(`Error: ${error.message}`);
        Alert.alert('Error', `Failed to write: ${error.message}`);
      }
    } finally {
      setIsScanning(false);
      await NfcManager.cancelTechnologyRequest();
    }
  };

  const stopScan = async () => {
    try {
      await NfcManager.cancelTechnologyRequest();
      setIsScanning(false);
      setStatusMessage('Scanning stopped');
    } catch (error) {
      console.error('Error stopping scan:', error);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.statusText}>{statusMessage}</Text>
      
      <TouchableOpacity
        style={[styles.button, !nfcAvailable && styles.buttonDisabled]}
        onPress={isScanning ? stopScan : (writeMode ? startWrite : startScan)}
        disabled={!nfcAvailable}
      >
        <Text style={styles.buttonText}>
          {isScanning ? 'Stop Scanning' : (writeMode ? 'Start Writing' : 'Start Scanning')}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  statusText: {
    fontSize: 16,
    marginBottom: 20,
    textAlign: 'center',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    minWidth: 200,
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    textAlign: 'center',
    fontWeight: 'bold',
  },
});
```

**Package Installation:**
```bash
# For React Native
npm install react-native-nfc-manager
npm install buffer  # For Buffer polyfill

# iOS setup (if using bare React Native)
cd ios && pod install

# Android setup - Add to AndroidManifest.xml
# <uses-permission android:name="android.permission.NFC" />
# <uses-feature android:name="android.hardware.nfc" android:required="false" />
```

#### Web (Limited Support - Chrome/Edge only)

Web NFC API has very limited browser support (mainly Chrome/Edge on Android). Consider this optional or use a fallback to QR codes.

```typescript
// components/rfid/WebNFCReader.tsx
'use client';

import { useState, useEffect } from 'react';

interface WebNFCReaderProps {
  onTagRead: (data: string) => void;
}

export function WebNFCReader({ onTagRead }: WebNFCReaderProps) {
  const [isSupported, setIsSupported] = useState(false);
  const [isScanning, setIsScanning] = useState(false);

  useEffect(() => {
    // Check if Web NFC is supported
    if ('NDEFReader' in window) {
      setIsSupported(true);
    }
  }, []);

  const startScan = async () => {
    if (!isSupported) {
      alert('NFC is not supported in this browser. Please use Chrome or Edge on Android.');
      return;
    }

    try {
      const reader = new (window as any).NDEFReader();
      
      setIsScanning(true);
      
      await reader.scan();
      
      reader.addEventListener('reading', (event: any) => {
        const { message } = event;
        
        if (message.records && message.records.length > 0) {
          const record = message.records[0];
          
          if (record.recordType === 'text') {
            const decoder = new TextDecoder();
            const text = decoder.decode(record.data);
            onTagRead(text);
          }
        }
      });

      reader.addEventListener('readingerror', () => {
        console.error('Error reading NFC tag');
        setIsScanning(false);
      });
    } catch (error: any) {
      console.error('NFC scan error:', error);
      alert(`Error: ${error.message}`);
      setIsScanning(false);
    }
  };

  if (!isSupported) {
    return (
      <div>
        <p>NFC is not supported in this browser.</p>
        <p>Please use Chrome or Edge on Android, or use the mobile app.</p>
      </div>
    );
  }

  return (
    <div>
      <button onClick={startScan} disabled={isScanning}>
        {isScanning ? 'Scanning...' : 'Start NFC Scan'}
      </button>
    </div>
  );
}
```

### RFID Scanner Screen Implementation

#### Complete React Native RFID Scanner Screen

```typescript
// screens/admin/RFIDScannerScreen.tsx
import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Alert, ActivityIndicator } from 'react-native';
import { RFIDScanner } from '@/components/rfid/RFIDScanner';
import { useAuthStore } from '@/stores/authStore';
import { useAttendanceStore } from '@/stores/attendanceStore';
import { useEventStore } from '@/stores/eventStore';

export function RFIDScannerScreen({ route }: any) {
  const { selectedEvent } = route.params || {};
  const { user } = useAuthStore();
  const { markAttendance } = useAttendanceStore();
  const { events } = useEventStore();
  
  const [isWriteMode, setIsWriteMode] = useState(false);
  const [selectedStudent, setSelectedStudent] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [statusMessage, setStatusMessage] = useState('Ready to scan');

  const handleTagRead = async (tagData: string) => {
    if (isProcessing) return;
    
    setIsProcessing(true);
    setStatusMessage('Processing tag data...');

    try {
      // Parse tag data (can be base64 JSON or plain student ID)
      let eventId: string;
      let studentId: string;

      try {
        // Try to decode as base64 JSON
        const decoded = Buffer.from(tagData, 'base64').toString('utf-8');
        const payload = JSON.parse(decoded);
        
        if (payload.eventId && payload.studentId) {
          eventId = payload.eventId;
          studentId = payload.studentId;
        } else if (payload.studentId) {
          studentId = payload.studentId;
          eventId = selectedEvent?.id || (await promptEventSelection());
          if (!eventId) return;
        } else {
          throw new Error('Invalid payload format');
        }
      } catch {
        // If not JSON, treat as plain student ID
        studentId = tagData;
        eventId = selectedEvent?.id || (await promptEventSelection());
        if (!eventId) return;
      }

      // Mark attendance
      const result = await markAttendance({
        eventId,
        studentId,
        qrCodeData: tagData,
      });

      if (result.success) {
        setStatusMessage(`Attendance marked: ${result.action}`);
        Alert.alert('Success', `Student ${result.action} successfully`);
      } else {
        setStatusMessage(`Error: ${result.message}`);
        Alert.alert('Error', result.message);
      }
    } catch (error: any) {
      setStatusMessage(`Error: ${error.message}`);
      Alert.alert('Error', error.message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleWriteTag = async (tagData: string) => {
    if (!selectedStudent) {
      Alert.alert('Error', 'Please select a student first');
      return;
    }

    // Tag was written, show success
    Alert.alert('Success', `Student data written to RFID tag`);
    setStatusMessage('Data written successfully');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>RFID/NFC Scanner</Text>
      
      {selectedEvent && (
        <View style={styles.eventInfo}>
          <Text style={styles.eventTitle}>Event: {selectedEvent.title}</Text>
        </View>
      )}

      <View style={styles.modeToggle}>
        <Text
          style={[styles.modeButton, !isWriteMode && styles.modeButtonActive]}
          onPress={() => setIsWriteMode(false)}
        >
          Read Mode
        </Text>
        <Text
          style={[styles.modeButton, isWriteMode && styles.modeButtonActive]}
          onPress={() => setIsWriteMode(true)}
        >
          Write Mode
        </Text>
      </View>

      {isProcessing && (
        <View style={styles.processing}>
          <ActivityIndicator size="large" />
          <Text>{statusMessage}</Text>
        </View>
      )}

      <RFIDScanner
        onTagRead={handleTagRead}
        writeMode={isWriteMode}
        dataToWrite={isWriteMode && selectedStudent ? JSON.stringify({
          studentId: selectedStudent.id,
          eventId: selectedEvent?.id,
        }) : undefined}
      />

      <Text style={styles.statusText}>{statusMessage}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  eventInfo: {
    backgroundColor: '#f0f0f0',
    padding: 10,
    borderRadius: 8,
    marginBottom: 20,
  },
  eventTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  modeToggle: {
    flexDirection: 'row',
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
  },
  modeButton: {
    flex: 1,
    padding: 10,
    textAlign: 'center',
    backgroundColor: '#fff',
  },
  modeButtonActive: {
    backgroundColor: '#007AFF',
    color: '#fff',
  },
  processing: {
    alignItems: 'center',
    marginVertical: 20,
  },
  statusText: {
    marginTop: 20,
    textAlign: 'center',
    color: '#666',
  },
});
```

### Important Notes on RFID/NFC Migration

1. **Platform Support:**
   - **iOS**: Full support via `react-native-nfc-manager` (iOS 11+)
   - **Android**: Full support via `react-native-nfc-manager`
   - **Web**: Limited support (Chrome/Edge on Android only) - consider QR code fallback

2. **Permissions:**
   - **iOS**: Add `NFCReaderUsageDescription` to `Info.plist`
   - **Android**: Add NFC permission to `AndroidManifest.xml`
   - **Web**: Requires HTTPS and user gesture

3. **Data Format:**
   - The app uses base64-encoded JSON for tag data
   - Format: `{ "eventId": "...", "studentId": "..." }`
   - Consider adding error handling for different tag formats

4. **Write Mode:**
   - Only works with NDEF-formatted tags
   - Some tags may be read-only
   - Always handle write failures gracefully

5. **Testing:**
   - Test on real devices (emulators don't support NFC)
   - Test with different tag types (NDEF, NTAG, etc.)
   - Test error scenarios (no tag, read-only tag, etc.)

### Example 6: API Route Migration

#### PHP (Original)
```php
<?php
// backend/api/events/list.php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../../config/database.php';

$db = Database::connect();
$stmt = $db->query('SELECT * FROM events ORDER BY start_time DESC');
$events = $stmt->fetchAll();

echo json_encode(['success' => true, 'events' => $events]);
?>
```

#### Next.js API Route (Migrated)
```typescript
// app/api/events/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { events } from '@/lib/db/schema';

export async function GET(request: NextRequest) {
  try {
    const eventsList = await db.select().from(events)
      .orderBy(events.startTime);
    
    return NextResponse.json({
      success: true,
      events: eventsList,
    });
  } catch (error) {
    return NextResponse.json(
      { success: false, message: 'Failed to fetch events' },
      { status: 500 }
    );
  }
}
```

#### Node.js/Express (Alternative)
```typescript
// routes/events.ts
import { Router } from 'express';
import { db } from '../lib/db';

const router = Router();

router.get('/events', async (req, res) => {
  try {
    const events = await db.select().from('events')
      .orderBy('start_time', 'desc');
    
    res.json({ success: true, events });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Failed to fetch events' });
  }
});

export default router;
```

---

## Database Considerations

### Option 1: Keep MySQL, Use Prisma ORM (Recommended)
```typescript
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

model User {
  id          String   @id @default(uuid())
  name        String
  email       String   @unique
  passwordHash String  @map("password_hash")
  studentId   String?  @map("student_id")
  yearLevel   String?  @map("year_level")
  department  String?
  course      String?
  gender      String?
  birthdate   DateTime?
  role        String   @default("student")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  @@map("users")
}

model Event {
  id              String   @id @default(uuid())
  title           String
  description     String
  startTime       DateTime @map("start_time")
  endTime         DateTime @map("end_time")
  location        String
  organizer       String?
  createdBy       String   @map("created_by")
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")
  isActive        Boolean  @default(true) @map("is_active")
  thumbnail       String?
  targetDepartment String? @map("target_department")
  targetCourse    String?  @map("target_course")
  targetYearLevel String?  @map("target_year_level")

  attendances     Attendance[]
  surveys         Survey[]

  @@map("events")
}

model Attendance {
  id           String    @id @default(uuid())
  eventId      String    @map("event_id")
  userId       String    @map("user_id")
  studentId    String    @map("student_id")
  studentName  String    @map("student_name")
  checkInTime  DateTime? @map("check_in_time")
  checkOutTime DateTime? @map("check_out_time")
  status       String    @default("present")
  notes        String?
  createdAt    DateTime  @default(now()) @map("created_at")

  event        Event     @relation(fields: [eventId], references: [id])

  @@map("attendance")
}
```

### Option 2: Use TypeORM
```typescript
// entities/User.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  email: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ name: 'student_id', nullable: true })
  studentId?: string;

  @Column({ name: 'year_level', nullable: true })
  yearLevel?: string;

  @Column({ nullable: true })
  department?: string;

  @Column({ nullable: true })
  course?: string;

  @Column({ nullable: true })
  gender?: string;

  @Column({ type: 'date', nullable: true })
  birthdate?: Date;

  @Column({ default: 'student' })
  role: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
```

---

## Backend Migration Options

### Option 1: Next.js API Routes (Recommended for Small-Medium Apps)

**Pros:**
- Same codebase as frontend
- Easy deployment (Vercel)
- Built-in TypeScript support
- File-based routing

**Cons:**
- Can become complex for large apps
- Serverless limitations

**Example Structure:**
```
app/
├── api/
│   ├── auth/
│   │   ├── login/route.ts
│   │   └── register/route.ts
│   ├── events/
│   │   ├── route.ts
│   │   └── [id]/route.ts
│   └── attendance/
│       └── route.ts
```

### Option 2: Separate Node.js/Express Backend

**Pros:**
- Separation of concerns
- More control over server
- Can use WebSockets easily
- Better for microservices

**Cons:**
- Separate deployment
- More infrastructure

**Example Setup:**
```typescript
// server/index.ts
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import eventRoutes from './routes/events';

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);

app.listen(3001, () => {
  console.log('Server running on port 3001');
});
```

### Option 3: NestJS (For Large-Scale Applications)

**Pros:**
- Enterprise-grade architecture
- Built-in dependency injection
- Great for complex apps
- Excellent documentation

**Cons:**
- Steeper learning curve
- More boilerplate

---

## Testing Strategy

### Unit Tests

#### Jest + React Testing Library (Web)
```typescript
// __tests__/components/QRCodeDisplay.test.tsx
import { render, screen } from '@testing-library/react';
import { QRCodeDisplay } from '@/components/qr/QRCodeDisplay';

describe('QRCodeDisplay', () => {
  it('renders QR code with correct data', () => {
    render(<QRCodeDisplay eventId="123" studentId="456" />);
    // Add assertions
  });
});
```

#### Jest + React Native Testing Library (Mobile)
```typescript
// __tests__/components/QRCodeDisplay.test.tsx
import { render } from '@testing-library/react-native';
import { QRCodeDisplay } from '@/components/qr/QRCodeDisplay';

describe('QRCodeDisplay', () => {
  it('renders QR code', () => {
    const { getByTestId } = render(
      <QRCodeDisplay eventId="123" studentId="456" />
    );
    // Add assertions
  });
});
```

### Integration Tests

```typescript
// __tests__/integration/auth.test.ts
import { apiClient } from '@/lib/api/client';

describe('Authentication API', () => {
  it('should login successfully', async () => {
    const response = await apiClient.post('/auth/login', {
      email: 'test@example.com',
      password: 'password123',
    });
    
    expect(response.data.success).toBe(true);
    expect(response.data.user).toBeDefined();
  });
});
```

### E2E Tests

#### Playwright (Web)
```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test('user can login', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[name="email"]', 'test@example.com');
  await page.fill('input[name="password"]', 'password123');
  await page.click('button[type="submit"]');
  
  await expect(page).toHaveURL('/dashboard');
});
```

#### Detox (React Native)
```typescript
// e2e/auth.e2e.ts
describe('Authentication', () => {
  it('should login successfully', async () => {
    await element(by.id('email-input')).typeText('test@example.com');
    await element(by.id('password-input')).typeText('password123');
    await element(by.id('login-button')).tap();
    
    await expect(element(by.id('dashboard'))).toBeVisible();
  });
});
```

---

## Deployment Considerations

### Web (Next.js)

#### Vercel (Recommended)
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel
```

**Environment Variables:**
```
DATABASE_URL=mysql://user:pass@host:3306/dbname
NEXT_PUBLIC_API_BASE_URL=https://api.example.com
JWT_SECRET=your-secret-key
```

#### Docker Deployment
```dockerfile
# Dockerfile
FROM node:18-alpine AS base
RUN npm install -g pnpm

FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
CMD ["node", "server.js"]
```

### Mobile (React Native)

#### Expo (Easiest)
```bash
# Build for production
eas build --platform ios
eas build --platform android

# Submit to stores
eas submit --platform ios
eas submit --platform android
```

#### Bare React Native
```bash
# Android
cd android
./gradlew assembleRelease

# iOS
cd ios
xcodebuild -workspace YourApp.xcworkspace -scheme YourApp archive
```

---

## Common Challenges & Solutions

### Challenge 1: State Management Across Platforms

**Solution:** Use Zustand or Redux Toolkit with platform-specific persistence middleware.

```typescript
// Web: localStorage
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

// Mobile: AsyncStorage
import AsyncStorage from '@react-native-async-storage/async-storage';
```

### Challenge 2: Camera Permissions

**Solution:** Use platform-specific permission handling.

```typescript
// Web: Browser APIs
const stream = await navigator.mediaDevices.getUserMedia({ video: true });

// Mobile: Expo Permissions or React Native Permissions
import { Camera } from 'expo-camera';
const { status } = await Camera.requestCameraPermissionsAsync();
```

### Challenge 3: Offline Support

**Solution:** Implement service workers for web and async storage for mobile.

```typescript
// Web: Service Worker + IndexedDB
// Mobile: AsyncStorage + Background sync
```

### Challenge 4: QR Code Scanning on Web

**Solution:** Use html5-qrcode library which supports web cameras.

```typescript
import { Html5Qrcode } from 'html5-qrcode';
```

### Challenge 5: Authentication Token Management

**Solution:** Use secure storage solutions.

```typescript
// Web: httpOnly cookies or localStorage
// Mobile: SecureStore (Expo) or Keychain (React Native)
```

### Challenge 6: RFID/NFC Functionality

**Solution:** Use `react-native-nfc-manager` for mobile, with Web NFC API fallback for web (limited support).

**Key Considerations:**
- **Platform Support**: iOS (11+) and Android fully supported. Web support is very limited (Chrome/Edge on Android only).
- **Permissions**: Must request NFC permissions on both iOS and Android.
- **Testing**: Requires physical devices - emulators don't support NFC.
- **Data Format**: Handle multiple tag formats (NDEF, raw tag IDs, etc.).
- **Error Handling**: Tags may be read-only, corrupted, or incompatible.

```typescript
// Mobile: react-native-nfc-manager
import NfcManager, { NfcTech, Ndef } from 'react-native-nfc-manager';

// Check availability
const isSupported = await NfcManager.isSupported();
if (!isSupported) {
  // Fallback to QR codes
}

// Read tag
await NfcManager.requestTechnology(NfcTech.Ndef);
const tag = await NfcManager.getTag();

// Write tag (requires NDEF format)
const bytes = Ndef.encodeMessage([Ndef.textRecord(data)]);
await NfcManager.ndefHandler.writeNdefMessage(bytes);

// Web: Limited support
if ('NDEFReader' in window) {
  const reader = new NDEFReader();
  await reader.scan();
}
```

**Best Practices:**
1. Always check NFC availability before attempting to use it
2. Implement QR code fallback for unsupported platforms
3. Handle read-only tags gracefully in write mode
4. Add proper error messages for users
5. Test with multiple tag types (NTAG213, NTAG215, NTAG216, etc.)
6. Consider adding a tag format validation step

### Challenge 7: Database Connection Pooling

**Solution:** Use connection pooling libraries.

```typescript
// With Prisma
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
});
```

---

## Migration Checklist

### Pre-Migration
- [ ] Backup existing database
- [ ] Document all API endpoints
- [ ] List all dependencies
- [ ] Create migration timeline
- [ ] Set up new project repositories

### Backend Migration
- [ ] Set up database ORM (Prisma/TypeORM)
- [ ] Migrate authentication system
- [ ] Migrate all API endpoints
- [ ] Implement error handling
- [ ] Add API documentation (OpenAPI/Swagger)
- [ ] Set up logging and monitoring

### Web Frontend Migration
- [ ] Set up Next.js project
- [ ] Migrate authentication flow
- [ ] Migrate user models and stores
- [ ] Migrate event management
- [ ] Migrate QR code generation
- [ ] Migrate admin dashboard
- [ ] Migrate student dashboard
- [ ] Migrate officer dashboard
- [ ] Implement responsive design
- [ ] Add error boundaries

### Mobile Frontend Migration
- [ ] Set up React Native project
- [ ] Migrate authentication screens
- [ ] Migrate QR code scanning
- [ ] Migrate RFID/NFC scanner (read mode)
- [ ] Migrate RFID/NFC writer (write mode)
- [ ] Configure NFC permissions (iOS & Android)
- [ ] Test NFC on real devices (iOS & Android)
- [ ] Implement QR code fallback for NFC-unavailable devices
- [ ] Migrate student features
- [ ] Migrate admin features
- [ ] Migrate officer features
- [ ] Implement offline support
- [ ] Test on iOS and Android

### Testing
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Write E2E tests
- [ ] Performance testing
- [ ] Security audit

### Deployment
- [ ] Set up production database
- [ ] Configure environment variables
- [ ] Deploy backend
- [ ] Deploy web frontend
- [ ] Build mobile apps
- [ ] Submit to app stores (if needed)
- [ ] Set up monitoring
- [ ] Create deployment documentation

### Post-Migration
- [ ] User acceptance testing
- [ ] Performance monitoring
- [ ] Bug fixes
- [ ] Documentation updates
- [ ] Training materials
- [ ] Decommission old system

---

## Additional Resources

### Documentation
- [Next.js Documentation](https://nextjs.org/docs)
- [React Native Documentation](https://reactnative.dev/docs/getting-started)
- [Expo Documentation](https://docs.expo.dev/)
- [Zustand Documentation](https://zustand-demo.pmnd.rs/)
- [Prisma Documentation](https://www.prisma.io/docs)

### Libraries & Tools
- **State Management**: Zustand, Redux Toolkit, Jotai
- **HTTP Clients**: Axios, SWR, TanStack Query
- **Forms**: React Hook Form, Formik
- **UI Components**: Material-UI, Chakra UI, React Native Paper
- **QR Codes**: qrcode.react, react-native-qrcode-svg, html5-qrcode
- **RFID/NFC**: react-native-nfc-manager, react-native-nfc (mobile), Web NFC API (web)
- **Date Handling**: date-fns, dayjs
- **Testing**: Jest, React Testing Library, Playwright, Detox

### Best Practices
1. Use TypeScript for type safety
2. Implement proper error handling
3. Use environment variables for configuration
4. Follow security best practices (JWT, password hashing)
5. Implement proper logging
6. Use code splitting for performance
7. Implement proper loading states
8. Handle offline scenarios
9. Test on real devices
10. Monitor performance and errors

---

## Timeline Estimate

**Total Estimated Time: 16-20 weeks**

- **Week 1-2**: Setup and planning
- **Week 3-5**: Backend migration
- **Week 6-8**: Web frontend core features
- **Week 9-11**: Mobile frontend core features
- **Week 12-14**: Advanced features
- **Week 15-16**: Testing and bug fixes
- **Week 17-18**: Deployment and migration
- **Week 19-20**: Buffer for unexpected issues

---

## Conclusion

This migration guide provides a comprehensive roadmap for migrating your Flutter QR Attendance App to React/Next.js (web) and React Native (mobile). The migration requires careful planning, but the benefits include:

- **Shared Code**: TypeScript types and business logic can be shared
- **Modern Stack**: Access to latest React ecosystem
- **Better Web Experience**: Next.js provides excellent SEO and performance
- **Native Performance**: React Native provides near-native performance
- **Ecosystem**: Large community and extensive libraries

Remember to:
1. Start with a pilot/mvp
2. Migrate incrementally
3. Test thoroughly at each stage
4. Keep the old system running during migration
5. Plan for rollback if needed
6. Communicate changes to users

Good luck with your migration!

