# ControlEx - Comprehensive Project Documentation

**Version:** 3.1.0  
**Project Name:** IoT Dashboard Project  
**Description:** A modern, feature-rich IoT control dashboard with real-time widget management, device control, and user authentication.

---

## 1. Project Overview

### 1.1 What is ControlEx?

**ControlEx** is a modern, production-ready IoT Dashboard platform designed for controlling smart devices and monitoring IoT sensors remotely. It provides users with a comprehensive web-based control panel to manage multiple IoT devices through a unified, intuitive interface.

### 1.2 Core Purpose

- **Primary Goal**: Enable users to create, configure, and manage interactive widgets (toggles, sliders, sensors, joysticks, terminal emulators) to control IoT devices
- **Target Users**: IoT enthusiasts, developers, hobby engineers, and smart home automation users
- **Key Value Proposition**: 
  - Easy-to-use drag-and-drop widget management
  - Real-time device communication
  - Secure user authentication with Google OAuth and 2FA support
  - Adafruit IO integration for cloud-based IoT control
  - Responsive design for desktop and mobile devices
  - Offline support with Progressive Web App (PWA) capabilities

### 1.3 Main Features at a Glance

✅ **User Authentication**: Email/password signup, Google OAuth 2.0, Two-Factor Authentication (2FA)  
✅ **Device Control**: Create and manage interactive widgets (toggles, sliders, joysticks, sensors, terminals)  
✅ **Real-Time Updates**: Socket.IO for instant device feedback and status updates  
✅ **Adafruit IO Integration**: Connect to Adafruit feeds for cloud-based IoT control  
✅ **Responsive Design**: Fully optimized for desktop and mobile devices  
✅ **Account Management**: User profiles, password reset, security settings, session management  
✅ **Data Import/Export**: Backup and restore widget configurations  
✅ **PWA Support**: Install as a native app, offline access capabilities

---

## 2. Tech Stack

### 2.1 Frontend Technologies

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Language** | Vanilla JavaScript (ES6+) | Latest | Core frontend logic without heavy frameworks |
| **DOM Management** | DOM API | Native | Direct HTML element manipulation |
| **Layout** | Grid Stack JS | 10.1.2 | Drag-and-drop widget grid management |
| **Styling** | CSS3 | Native | Modern styling with CSS variables and flexbox |
| **Real-Time** | Socket.IO Client | 4.8.1 | WebSocket communication with backend |
| **Icons** | Font Awesome | 6.5.1 | UI icons and visual elements |
| **Fonts** | Google Fonts (Tajawal) | - | Arabic-friendly, modern typography |
| **PWA** | Service Workers (SW) | Native | Offline support and app-like experience |

**Frontend Structure:**
```
public/
├── js/
│   ├── auth.js - Authentication handling
│   ├── auth-check.js - Auth token validation
│   ├── dashboard.js - Main dashboard logic
│   ├── settings.js - Widget configuration
│   ├── account.js - Account management
│   ├── forgot-reset.js - Password recovery
│   ├── icon-picker.js - Icon selection for widgets
│   ├── password-toggle.js - Show/hide password
│   ├── index.js - Login page logic
│   ├── toast-notifications.js - Toast UI system
│   ├── support-fab.js - Floating action button
│   ├── support-modal.js - Modal dialogs
│   ├── test-connection.js - Test Adafruit connection
│   └── sw.js - Service Worker for PWA
├── css/
│   ├── style.css - Main stylesheet (30KB+)
│   ├── joystick.css - Joystick widget styling
│   └── auth-buttons.css - Authentication UI
└── icons/ & images/ - Asset resources
```

### 2.2 Backend Technologies

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Runtime** | Node.js | ≥16.0.0 | JavaScript server runtime |
| **Web Framework** | Express.js | 4.19.2 | HTTP server and routing |
| **Database** | MongoDB | 8.4.1 (Mongoose) | NoSQL database for persistence |
| **Authentication** | JWT (jsonwebtoken) | 9.0.2 | Token-based authentication |
| **Real-Time** | Socket.IO | 4.8.1 | WebSocket server for live updates |
| **OAuth 2.0** | Passport.js + Google Strategy | 0.7.0 | Google login integration |
| **Password Hashing** | bcryptjs | 2.4.3 | Secure password encryption |
| **Session Management** | express-session | 1.18.2 | User session handling |
| **Email Service** | Nodemailer | 6.9.13 | Password reset email functionality |
| **Security** | Helmet.js | 7.1.0 | HTTP security headers |
| **Rate Limiting** | express-rate-limit | 7.3.1 | DDoS and brute force protection |
| **CORS** | cors | 2.8.5 | Cross-origin resource sharing |
| **Compression** | compression | 1.7.4 | Gzip response compression |
| **HTTP Logging** | Morgan | 1.10.0 | Request logging middleware |
| **Scheduled Tasks** | node-cron | 3.0.3 | Automated cron jobs |
| **HTTP Client** | node-fetch | 2.7.0 | Make HTTP requests to Adafruit |
| **Cloud Storage** | Firebase | 12.3.0 | Optional cloud integration |
| **Process Logging** | Winston | 3.13.0 | Application logging system |

**Backend Structure:**
```
server.js (Main application file)
├── Configuration (MongoDB, Passport, Sessions)
├── Mongoose Schemas
│   ├── UserSchema - User accounts and settings
│   ├── WidgetSchema - Widget configurations
│   ├── TerminalMessageSchema - Terminal I/O history
│   ├── SessionSchema - Active sessions
│   └── ResetCodeSchema - Password reset codes
├── AuthService - Password hashing, JWT generation
├── Authentication Middleware - Token verification
├── API Routes (40+ endpoints)
└── Socket.IO Event Handlers
```

### 2.3 External APIs & Services

| Service | Purpose | Integration |
|---------|---------|------------|
| **Adafruit IO** | IoT device data feeds | HTTP API for sending/receiving commands |
| **Google OAuth** | Third-party authentication | Google Sign-In for user accounts |
| **Email Service** | Password reset notifications | Nodemailer SMTP integration |
| **Socket.IO** | Real-time bidirectional communication | WebSocket server |

### 2.4 Development Tools

| Tool | Purpose |
|------|---------|
| **nodemon** | Auto-restart server on file changes |
| **npm** | Package management |
| **.env** | Environment variable configuration |

---

## 3. Site Map & Pages

### 3.1 List of All Pages/Routes

| Route | File | Name | Purpose | Auth Required |
|-------|------|------|---------|:-------------:|
| `/` | `index.html` | Login Page | User authentication and signup | ❌ |
| `/dashboard` | `dashboard.html` | Main Dashboard | Widget management & device control | ✅ |
| `/settings` | `settings.html` | Settings Page | Create and configure widgets | ✅ |
| `/account` | `account.html` | Account Management | User profile and security settings | ✅ |
| `/forgot-password` | `forgot-password.html` | Forgot Password | Password recovery flow | ❌ |
| `/reset-password` | `reset-password.html` | Reset Password | Password reset with code | ❌ |
| `/offline` | `offline.html` | Offline Page | PWA offline fallback | - |

### 3.2 Detailed Page Documentation

#### **3.2.1 Login Page (`/` → `index.html`)**

**Purpose:** User authentication entry point for the application

**Key UI Elements:**
- Email/Username input field
- Password input field with visibility toggle
- "Login" button with loading state
- "Don't have an account?" signup link
- "Forgot Password?" link
- **Google Sign-In button** (OAuth integration)
- Dark-themed glassmorphism card design
- Error message display area
- Loading spinner during auth

**Functionality:**
- Email/password validation
- Form submission to `/api/auth/login` endpoint
- Token storage in localStorage
- Redirect to dashboard on success
- Error notifications for invalid credentials
- Google OAuth integration for social login

**Styling Highlights:**
- Gradient background with violet (`#8A2BE2`) and cyan (`#00e5ff`) accents
- Backdrop blur effect for glass card effect
- Responsive design (mobile-first)
- RTL (right-to-left) support for Arabic

---

#### **3.2.2 Dashboard Page (`/dashboard` → `dashboard.html`)**

**Purpose:** Main control center where users view and interact with their widgets

**Key UI Elements:**
- **Header**: Logo, navigation menu, user profile dropdown
- **Sidebar**: Navigation links (Dashboard, Settings, Account, Logout)
- **Mobile Hamburger Menu**: Collapsible navigation for mobile devices
- **Overlay Sidebar**: Slides in from left on mobile
- **Main Grid Container**: Gridstack.js drag-and-drop widget grid
- **Widget Cards**: Dynamic widget containers with different types
- **Add Widget Button**: Floating action button to trigger widget creation
- **Edit Mode Toggle**: Button to enable/disable widget repositioning
- **Loading Overlay**: Full-page loader for initial load
- **Toast Notifications**: Bottom-right notification system
- **User Statistics**: Dashboard stats display area

**Widget Types Available:**
1. **Toggle Widget** (`toggle`) - On/off button for devices
2. **Push Widget** (`push`) - Single-action button to send a command
3. **Sensor Widget** (`sensor`) - Display real-time sensor values (temperature, humidity, etc.)
4. **Terminal Widget** (`terminal`) - Text input/output interface for device communication
5. **Slider Widget** (`slider`) - Numeric value control with min/max range
6. **Joystick Widget** (`joystick`) - 8-directional control interface (up, down, left, right, diagonals)

**Key Features:**
- **Real-Time Updates**: Socket.IO connection for instant widget state changes
- **Drag-and-Drop**: Reposition widgets using Gridstack.js
- **Web Sockets**: Live feed value updates from devices
- **Responsive Grid**: Adapts to screen size and device orientation
- **Widget Customization**: Icons, colors, commands per widget
- **Local Sync**: Refresh interval for periodic data updates
- **Statistics Panel**: Display user stats (total commands, success rate, etc.)
- **Session Management**: Active session tracking and display

**Data Management:**
- Widgets loaded from database via `/api/widgets` GET
- Widget positions saved via `/api/widgets/:widgetId/position` PUT
- Commands sent via `/api/command/send` POST
- Terminal messages fetched via `/api/terminals/:widgetId/messages` GET

---

#### **3.2.3 Settings Page (`/settings` → `settings.html`)**

**Purpose:** Widget creation and configuration interface

**Key UI Elements:**
- **Page Header**: Title and subtitle
- **Widget Creation Form**: Multi-section form with fieldsets
- **Basic Information Section**:
  - Widget Name (text input)
  - Feed Name (connected Adafruit feed)
  - Widget Type (dropdown: toggle, push, sensor, terminal, slider, joystick)
  - Icon Picker (modal for selecting Font Awesome icons)

- **Configuration Section**:
  - ON Command (text input)
  - OFF Command (text input)
  - Unit (text input, e.g., "°C", "%", "V")
  - Min Value (number for sliders)
  - Max Value (number for sliders)
  - **Joystick-specific commands**:
    - Up Command, Down Command, Left Command, Right Command
    - Up-Right, Up-Left, Down-Right, Down-Left diagonal commands

- **Appearance Section**:
  - Primary Color (color picker)
  - Active Color (color picker)
  - Glow Color (color picker)

- **Configured Widgets List**: Display of all created widgets with:
  - Widget name and type
  - Feed name
  - Edit button (to modify widget)
  - Delete button (to remove widget)
  - Test button (to verify Adafruit connection)

- **Icon Picker Modal**: Searchable, keyboard-navigable modal for selecting from Font Awesome icons

**Functionality:**
- Form submission to `/api/widgets` POST to create new widgets
- PUT to `/api/widgets/:id` to update existing widgets
- DELETE to `/api/widgets/:id` to remove widgets
- Live icon search and preview
- Color picker with validation
- Adafruit feed name validation
- Command validation for device control
- Success/error toast notifications

---

#### **3.2.4 Account Page (`/account` → `account.html`)**

**Purpose:** User profile management and security configuration

**Key UI Elements:**
- **Account Information Section**:
  - Username (display-only)
  - Email (display-only)
  - Adafruit Username (display-only)
  - Account Creation Date (display-only)
  - Last Login Timestamp (display-only)

- **Account Update Form**:
  - Username input (with 3-50 character validation)
  - Email input (with email validation)
  - New Password input (optional, 6+ characters)
  - Password strength indicator
  - Password feedback messages
  - Form submit button
  - Change Password button

- **Adafruit Settings Section**:
  - Adafruit Username input
  - Adafruit API Key input (password field with toggle visibility)
  - Save button
  - Link to Adafruit.io website

- **Security Settings Section**:
  - Two-Factor Authentication (2FA) toggle
  - Generate 2FA code option
  - Active sessions list with device info
  - Session termination buttons
  - Last login timestamp per session

- **Data Management Section**:
  - Export user data button (backup all widgets)
  - Import user data button (restore from backup)
  - Clear all data button
  - Delete account button (irreversible)

**Functionality:**
- Update user profile via `/api/user/update` PUT
- Update Adafruit credentials via `/api/user/update` PUT
- Enable/disable 2FA via `/api/user/enable-2fa` and `/api/user/disable-2fa` POST
- View active sessions via `/api/user/sessions` GET
- Terminate sessions via `/api/user/sessions/:sessionId` DELETE
- Export configuration via `/api/user/export` GET
- Import configuration via `/api/user/import` POST
- Delete account via `/api/user/delete-account` DELETE
- Password strength validation in real-time

---

#### **3.2.5 Forgot Password Page (`/forgot-password` → `forgot-password.html`)**

**Purpose:** Initiate password recovery process

**Key UI Elements:**
- **Card Container**: Centered, glassmorphic design
- **Title**: "نسيت كلمة المرور؟" (Forgot Password?)
- **Description Text**: Guidance message
- **Email Input**: User email field
- **Submit Button**: "إرسال كود إعادة التعيين" (Send Reset Code)
- **Message Display Area**: For success/error feedback
- **Login Link**: Return to login page

**Functionality:**
- Form submission to `/api/auth/forgot-password` POST
- Email validation
- Sends reset code via email
- Redirects to reset-password page after submission
- Error handling and display

---

#### **3.2.6 Reset Password Page (`/reset-password` → `reset-password.html`)**

**Purpose:** Verify reset code and set new password

**Key UI Elements:**
- **Card Container**: Centered layout matching forgot-password page
- **Reset Code Input**: 6-digit numeric code field
- **New Password Input**: Password field with visibility toggle
- **Confirm Password Input**: Password verification field
- **Verify & Reset Button**: Primary action
- **Resend Code Link**: Request new reset code
- **Back to Login Link**: Login page navigation

**Functionality:**
- Verify reset code via `/api/auth/verify-reset-code` POST
- Set new password via `/api/auth/reset-password` POST
- Password validation (minimum 6 characters)
- Password confirmation match
- Success notification and redirect to login
- Code expiration handling (6 digits, 10-minute TTL)

---

#### **3.2.7 Offline Page (`/offline` → `offline.html`)**

**Purpose:** Fallback page for PWA offline mode

**Key UI Elements:**
- Offline notification
- List of cached pages
- Retry connection button
- Service worker status indicator

**Functionality:**
- Served when network is unavailable
- Service worker intercepts requests
- Displays cached content when possible

---

### 3.3 Navigation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      ControlEx Navigation Flow              │
└─────────────────────────────────────────────────────────────┘

Unauthenticated Users:
    [Login Page] ──→ [Forgot Password] ──→ [Reset Password]
         ├─→ (Success) ──→ [Dashboard]
         └─→ [Create Account] ──→ [Dashboard]
         └─→ [Google OAuth] ──→ [Dashboard]

Authenticated Users:
    [Dashboard] ←→ [Settings] ←→ [Account]
         ↑                            ↓
         └──────────── [Logout] ──────┘
```

---

## 4. Core Features & Functionalities

### 4.1 User Authentication System

#### **Email/Password Authentication**
```
Flow: Register → Verify Email → Login → JWT Token
- Signup: POST /api/auth/register
  - Input: username, email, password
  - Validation: Email uniqueness, password strength
  - Output: User object + JWT token
  
- Login: POST /api/auth/login
  - Input: email, password
  - Output: JWT token + User info
  
- Token Storage: localStorage.token
```

#### **Google OAuth 2.0 Integration**
```
Flow: Click Google Button → Google Consent → Account Link → Dashboard
- Routes: /auth/google (redirect to Google)
- Callback: /auth/google/callback
- Link existing accounts: /api/user/unlink-google
- Automatic profile picture sync
```

#### **Two-Factor Authentication (2FA)**
```
- Enable: POST /api/auth/enable-2fa
- Verify: POST /api/auth/verify-2fa
- Disable: POST /api/user/disable-2fa
- Implementation: 6-digit code, email delivery
- Code Expiration: 15 minutes TTL
```

#### **Password Recovery**
```
Flow: Forgot Password → Email Code → Verify Code → Reset Password
- Step 1: POST /api/auth/forgot-password (send email)
- Step 2: POST /api/auth/verify-reset-code (validate code)
- Step 3: POST /api/auth/reset-password (set new password)
- Code TTL: 10 minutes
```

### 4.2 Widget Management System

#### **Widget Creation**
```
POST /api/widgets
{
  name: "Bedroom Light",
  feedName: "username/feeds/light",
  type: "toggle",  // Options: toggle, push, sensor, slider, joystick, terminal
  icon: "fas fa-lightbulb",
  configuration: {
    onCommand: "ON",
    offCommand: "OFF",
    unit: "",
    min: 0,
    max: 100
  },
  appearance: {
    primaryColor: "#8A2BE2",
    activeColor: "#00e5ff",
    glowColor: "#8A2BE2"
  }
}
```

#### **Widget Types & Commands**

**1. Toggle Widget**
- Sends ON/OFF commands to device
- State switches between two positions
- Visual: Button with on/off state

**2. Push Widget**
- Sends a single command on click
- No state persistence
- Use case: Open door, trigger alarm, take photo

**3. Sensor Widget**
- Displays real-time values from Adafruit feeds
- Updates every 5-30 seconds
- Shows: value + unit (e.g., "23.5°C")
- Use case: Temperature, humidity, voltage monitoring

**4. Terminal Widget**
- Text input field for custom commands
- Command history display
- Full message log with timestamps
- Bidirectional communication (sent/received)
- Storage: MongoDB TerminalMessage collection

**5. Slider Widget**
- Numeric value control in range [min, max]
- Visual: Draggable slider or number input
- Sends command format: `${value}` (e.g., "75" for brightness)
- Real-time feedback

**6. Joystick Widget**
- 8-directional control: North, East, South, West + Diagonals
- Commands: upCommand, downCommand, leftCommand, rightCommand, upRightCommand, etc.
- Use case: Robot movement, camera pan/tilt, directional control
- Visual: Interactive joystick interface

#### **Widget Operations**
```
GET /api/widgets
- Fetch all widgets for current user
- Returns: Array of widget objects with state

PUT /api/widgets/:id
- Update widget configuration
- Can modify name, commands, colors, icon

PUT /api/widgets/:widgetId/position
- Update widget position on grid (gs.x, gs.y, gs.w, gs.h)
- Called when user drags/resizes widget

DELETE /api/widgets/:id
- Remove widget from dashboard
- Cascade delete terminal messages

POST /api/command/send
- Send control command to Adafruit IO
- Input: widgetId, command
- Updates widget.state.lastValue
- Logs successful command count
```

#### **Widget State Management**
```
Each widget maintains:
- state.isActive: Boolean, current on/off state
- state.lastValue: Mixed type, last received value
- state.lastUpdate: Date, timestamp of last update
- analytics.totalCommands: Number of commands sent
- analytics.successfulCommands: Number of successful commands
```

### 4.3 Device Communication (Adafruit IO Integration)

#### **How Control Works**
```
1. User clicks widget in dashboard
2. JavaScript sends command to backend: POST /api/command/send
3. Backend authenticates request using JWT token
4. Backend fetches user's Adafruit credentials from database
5. Backend makes HTTP POST to Adafruit IO API:
   POST https://io.adafruit.com/api/v2/{username}/feeds/{feedName}/data
   with Authorization header
6. Adafruit IO forwards command to physical device (via WiFi, etc.)
7. Device receives and executes command (LED turns on, etc.)
8. Backend logs success and updates widget.state
9. Socket.IO sends real-time update to all connected clients
```

#### **Adafruit User Configuration**
```
User's Adafruit account stored in database:
{
  adafruitUsername: "john_doe",
  adafruitApiKey: "aio_a1B2c3D4e5F6g7H8i9J0k"  // Encrypted
}

Feeds configured in dashboard:
- Each widget points to 1 Adafruit feed
- Format: "username/feeds/feed-name"
- Example: "john_doe/feeds/bedroom-light"
```

#### **Real-Time Updates (Socket.IO)**
```
Server Events:
- 'widget-updated' - Widget state changed
- 'widget-created' - New widget added
- 'widget-deleted' - Widget removed
- 'feed-data' - New data from Adafruit feed
- 'command-executed' - Command sent successfully

Client Connection:
- Establishes on dashboard load
- Auto-reconnects on disconnect
- Listens for feed updates
- Updates widget display in real-time
```

### 4.4 Real-Time Terminal Widget

#### **Terminal Message System**
```
Database Model (TerminalMessageSchema):
{
  userId: ObjectId,
  widgetId: ObjectId,
  message: String,
  type: "sent" | "received",
  timestamp: Date,
  createdAt: Date
}

Operations:
GET /api/terminals/:widgetId/messages
- Fetch terminal history for a widget
- Limit: 100 most recent messages
- Ordered by timestamp

POST /api/command/send (with terminal widget)
- Send message to device
- Store in TerminalMessage collection
- Broadcast via Socket.IO
- Display in frontend terminal

Socket.IO Event: 'terminal-message'
- Real-time message arrival notification
- Update terminal display immediately
```

#### **Terminal UI Features**
- Message display area (scrollable)
- Input field for typing commands
- Visual distinction (sent vs. received messages)
- Timestamp for each message
- Clear history button
- Auto-scroll to latest message

### 4.5 Data Persistence & Backup

#### **Export/Import System**
```
GET /api/user/export
- Returns complete user configuration as JSON
- Includes: widgets, settings, preferences
- Use case: Data backup, account migration

POST /api/user/import
- Upload and restore from JSON backup
- Overwrites existing widgets
- Validates structure
- Error handling for corrupted files

POST /api/user/clear-data
- Delete all widgets for user
- Preserve account and settings
- Irreversible operation
```

### 4.6 User Preferences & Settings

#### **Stored Preferences**
```
Database: User.preferences
{
  theme: "dark" | "light",
  privacy: {
    allowDataCollection: Boolean,
    emailNotifications: Boolean,
    securityAlerts: Boolean
  }
}

Endpoint: PUT /api/user/preferences
- Update theme preference
- Control email notifications
- Control security alerts

Frontend Storage: localStorage
- token: JWT for authentication
- theme: User's theme preference
```

### 4.7 Security Features

#### **Password Security**
- Hashing: bcryptjs with salt rounds: 12
- Validation: Minimum 6 characters (frontend), recommended: mixed case + numbers + symbols
- Strength Indicator: Visual feedback on password quality
- Reset: 10-minute TTL code-based reset

#### **Session Security**
```
Session Management:
- JWT tokens: 3650 day expiration (practically never)
- HTTP-only cookies for session data
- Session tracking in database (SessionSchema)
- Device info logged: IP, browser, user agent
- Session termination: DELETE /api/user/sessions/:sessionId

Security Headers (Helmet.js):
- Content-Security-Policy: Restrict script sources
- X-Frame-Options: Prevent clickjacking
- X-Content-Type-Options: No MIME sniffing
- Strict-Transport-Security: Force HTTPS
```

#### **Rate Limiting**
```
express-rate-limit configuration:
- Login endpoint: 5 attempts/15 minutes
- Register endpoint: 3 attmpts/hour
- Password reset: 3 attempts/hour
- General API: 100 requests/15 minutes
```

#### **CORS Configuration**
```
Allowed origins:
- process.env.CLIENT_URL
- http://localhost:3000
- http://127.0.0.1:3000
- http://localhost:8080

Allowed headers:
- Content-Type
- x-auth-token
- Authorization
```

### 4.8 Analytics & Statistics

#### **User Statistics Endpoint**
```
GET /api/user/stats
Returns:
{
  totalWidgets: Number,
  totalCommands: Number,
  successfulCommands: Number,
  failedCommands: Number,
  successRate: Percentage,
  lastActivityDate: Date
}
```

#### **Widget Analytics**
```
Per-widget tracking:
- analytics.totalCommands: Count of all sent commands
- analytics.successfulCommands: Count of successful executions
- state.lastUpdate: Timestamp of last interaction
- state.lastValue: Last recorded value
```

### 4.9 Additional Features

#### **PWA Support**
- Service Worker (`sw.js`) for offline functionality
- Manifest file for installable app
- Offline page fallback
- Cache strategies for assets

#### **Theme Support**
- Dark theme (default): Violet + Cyan color scheme
- RT/LTL: Arabic (RTL) and English (LTR) language support
- Responsive design: Mobile, tablet, desktop layouts
- Color variables for easy customization

#### **Notifications System**
```
Toast Notifications:
- Success: Green background, checkmark icon
- Error: Red background, error icon
- Warning: Orange background, alert icon
- Info: Blue background, info icon

Duration: 3-5 seconds auto-dismiss
Position: Bottom-right on desktop, top-center on mobile
```

---

## 5. Component Architecture

### 5.1 Frontend Component Hierarchy

```
                    [App Container]
                           |
            _______________|_______________
           |                               |
      [Header]                        [Main Content]
           |                               |
      [Navigation]                   ____|____
           |                         |       |
      [Menu Items] ─────────→  [Sidebar]  [Page Content]
                                  |         |
                              [Nav Links]   └─── Selected Page:
                                           [Dashboard Page]
                                           [Settings Page]
                                           [Account Page]
```

### 5.2 JavaScript Module Structure

#### **Authentication & Session**
- `auth.js` - Login/signup form handling, API communication
- `auth-check.js` - Token validation, redirect unauthorized users
- `index.js` - Login page initialization, form submission

#### **Dashboard Management**
- `dashboard.js` - Main dashboard logic (1500+ lines)
  - Gridstack grid initialization
  - Widget loading and rendering
  - Socket.IO connection management
  - Command sending and event handling
  - Real-time update listeners
  - Auto-refresh intervals
  - User data display

#### **Settings & Configuration**
- `settings.js` - Widget creation and management (1000+ lines)
  - Form validation
  - Widget CRUD operations
  - Icon picker integration
  - Adafruit connection testing
  - Command preview

#### **Account Management**
- `account.js` - User profile and security (1200+ lines)
  - Profile information display
  - Account update forms
  - Adafruit credentials management
  - 2FA setup and toggles
  - Session management and termination
  - Data import/export
  - Account deletion

#### **Utility Modules**
- `icon-picker.js` - Modal icon selection (~400 Font Awesome icons)
- `password-toggle.js` - Show/hide password functionality
- `forgot-reset.js` - Password recovery flow
- `toast-notifications.js` - Notification system
- `support-fab.js` - Floating action button
- `support-modal.js` - Modal dialog framework
- `test-connection.js` - Adafruit API connectivity testing
- `sw.js` - Service Worker for PWA

### 5.3 Backend Route & API Structure

```
Express Application (server.js)
├── [Static File Serving]
│   └── app.use(express.static('public'))
│
├── [Page Routes - GET]
│   ├── / → index.html
│   ├── /dashboard → dashboard.html
│   ├── /settings → settings.html
│   ├── /account → account.html
│   ├── /forgot-password → forgot-password.html
│   ├── /reset-password → reset-password.html
│   └── /offline → offline.html
│
├── [Authentication Routes]
│   ├── OAuth
│   │   ├── GET /auth/google → Initiate Google login
│   │   ├── GET /auth/google/callback → Google callback handler
│   │   ├── GET /auth/google/link → Link Google to existing account
│   │   └── POST /api/user/unlink-google → Unlink Google account
│   │
│   ├── Email/Password
│   │   ├── POST /api/auth/register → Create new account
│   │   ├── POST /api/auth/login → Login with credentials
│   │   ├── POST /api/auth/logout → Logout and invalidate session
│   │   ├── POST /api/auth/forgot-password → Request password reset
│   │   ├── POST /api/auth/verify-reset-code → Validate reset code
│   │   ├── POST /api/auth/reset-password → Set new password
│   │   │
│   │   └── Two-Factor Auth
│   │       ├── POST /api/auth/enable-2fa → Generate and enable 2FA
│   │       ├── POST /api/auth/verify-2fa → Verify 2FA code
│   │       ├── POST /api/user/enable-2fa → Alternative 2FA enable
│   │       └── POST /api/user/disable-2fa → Disable 2FA
│   │
│   └── Complete Google Signup
│       └── POST /api/auth/complete-google-signup → Finalize Google signup
│
├── [User Management Routes] [AUTH REQUIRED]
│   ├── GET /api/user/me → Get current user profile
│   ├── GET /api/user/stats → Get user analytics
│   ├── PUT /api/user/update → Update username/email/password
│   ├── PUT /api/user/preferences → Update theme and settings
│   ├── PUT /api/user/update-google-picture → Sync Google profile pic
│   ├── GET /api/user/sessions → List active sessions
│   ├── DELETE /api/user/sessions/:sessionId → Terminate session
│   ├── GET /api/user/export → Export all data as JSON
│   ├── POST /api/user/import → Import data from JSON
│   ├── POST /api/user/clear-data → Delete all widgets/data
│   └── DELETE /api/user/delete-account → Completely delete account
│
├── [Widget Management Routes] [AUTH REQUIRED]
│   ├── GET /api/widgets → Fetch all user widgets
│   ├── POST /api/widgets → Create new widget
│   ├── PUT /api/widgets/:id → Update widget configuration
│   ├── PUT /api/widgets/:widgetId/position → Update widget grid position
│   └── DELETE /api/widgets/:id → Delete widget
│
├── [Device Control Routes] [AUTH REQUIRED]
│   ├── POST /api/command/send → Send command to Adafruit feed
│   ├── GET /api/feed/latest/:feedName → Get latest feed value
│   └── GET /api/sensors/:widgetId/data → Get sensor data
│
├── [Terminal Routes] [AUTH REQUIRED]
│   ├── GET /api/terminal/messages/:widgetId → Fetch terminal history
│   └── GET /api/terminals/:widgetId/messages → Alternative endpoint
│
└── [Socket.IO Events]
    ├── connect → Client connection event
    ├── widget-updated → Widget state changed
    ├── widget-created → New widget created
    ├── widget-deleted → Widget deleted
    ├── feed-data → New Adafruit feed data
    ├── command-executed → Command sent successfully
    ├── terminal-message → Terminal message received
    └── disconnect → Client disconnected
```

### 5.4 Database Schema Architecture

#### **User Schema**
```javascript
{
  _id: ObjectId,
  username: String (unique, required),
  password: String (bcrypt hash),
  email: String (unique, required),
  googleId: String (sparse, unique),
  googleEmail: String,
  googleProfilePicture: String (URL),
  adafruitUsername: String,
  adafruitApiKey: String,
  
  security: {
    lastLogin: Date,
    loginAttempts: Number,
    lockUntil: Date,
    twoFactorEnabled: Boolean,
    twoFactorCode: String,
    twoFactorCodeExpires: Date,
    resetPasswordToken: String,
    resetPasswordExpires: Date
  },
  
  preferences: {
    theme: String ("dark" | "light"),
    privacy: {
      allowDataCollection: Boolean,
      emailNotifications: Boolean,
      securityAlerts: Boolean
    }
  },
  
  timestamps: {
    createdAt: Date,
    updatedAt: Date
  }
}
```

#### **Widget Schema**
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: User, required),
  name: String (required),
  feedName: String (required),
  type: String ("toggle" | "push" | "sensor" | "slider" | "joystick" | "terminal"),
  icon: String (Font Awesome class),
  
  gs: {  // GridStack position
    x: Number,
    y: Number,
    w: Number,
    h: Number
  },
  
  configuration: {
    onCommand: String,
    offCommand: String,
    unit: String,
    min: Number,
    max: Number,
    upCommand: String,      // Joystick
    downCommand: String,    // Joystick
    leftCommand: String,    // Joystick
    rightCommand: String,   // Joystick
    upRightCommand: String, // Joystick diagonal
    upLeftCommand: String,  // Joystick diagonal
    downRightCommand: String, // Joystick diagonal
    downLeftCommand: String  // Joystick diagonal
  },
  
  appearance: {
    primaryColor: String (hex),
    activeColor: String (hex),
    glowColor: String (hex)
  },
  
  state: {
    isActive: Boolean,
    lastValue: Mixed,
    lastUpdate: Date
  },
  
  analytics: {
    totalCommands: Number,
    successfulCommands: Number
  },
  
  timestamps: {
    createdAt: Date,
    updatedAt: Date
  }
}
```

#### **Terminal Message Schema**
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: User, required),
  widgetId: ObjectId (ref: Widget, required),
  message: String (required),
  type: String ("sent" | "received", required),
  timestamp: Date (default: Date.now),
  
  timestamps: {
    createdAt: Date,
    updatedAt: Date
  }
}
```

#### **Session Schema**
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: User),
  token: String (JWT),
  
  deviceInfo: {
    browser: String,
    ip: String,
    userAgent: String
  },
  
  isActive: Boolean,
  lastActivity: Date,
  expiresAt: Date (24 hours default),
  
  timestamps: {
    createdAt: Date,
    updatedAt: Date
  }
}
```

#### **Reset Code Schema**
```javascript
{
  _id: ObjectId,
  email: String,
  code: String (6 digits),
  createdAt: Date (TTL: 10 minutes)
}
```

### 5.5 Service Architecture

#### **Authentication Service**
```
AuthService = {
  hashPassword(password) → Promise<hash>,
  verifyPassword(password, hash) → Promise<boolean>,
  generateJWT(payload) → String,
  verifyJWT(token) → Object,
  generateResetCode() → String (6 digits)
}
```

#### **Middleware Chain**
```
Request Flow:
1. express.static() - Serve static files
2. Content-Security-Policy header middleware
3. express.json() - Parse JSON body (50mb limit)
4. express.urlencoded() - Parse form data
5. cors() - Handle CORS
6. session() - Session middleware
7. passport.initialize() - Passport auth
8. passport.session() - Session support
9. Router (specific route handler)
10. auth middleware (for protected routes) - Validate JWT
```

#### **Auth Middleware**
```javascript
const auth = async (req, res, next) => {
  // Extracts token from headers or query params
  // Verifies JWT signature
  // Validates expiration
  // Attaches user ID to req.user.id
  // Throws 401 if invalid
}
```

---

## 6. Data Flow & State Management

### 6.1 Authentication Data Flow

```
┌─────────────────────────────────────────────────────────┐
│          Email/Password Authentication Flow             │
└─────────────────────────────────────────────────────────┘

Register:
[User fills signup form]
           ↓
[POST /api/auth/register with email, username, password]
           ↓
[Backend validates email uniqueness]
           ↓
[Hash password with bcryptjs (12 rounds)]
           ↓
[Create User document in MongoDB]
           ↓
[Generate JWT token (3650 day expiration)]
           ↓
[Return token + user info to frontend]
           ↓
[Frontend stores token in localStorage.token]
           ↓
[Redirect to dashboard]


Login:
[User fills login form with email/password]
           ↓
[POST /api/auth/login with credentials]
           ↓
[Backend finds user by email]
           ↓
[Compare password with bcrypt.compare()]
           ↓
[If match: Generate JWT token]
           ↓
[Store session in MongoDB SessionSchema]
           ↓
[Return token + user to frontend]
           ↓
[Frontend stores token in localStorage]
           ↓
[Redirect to dashboard]


Password Reset:
[User enters email on forgot-password page]
           ↓
[POST /api/auth/forgot-password]
           ↓
[Generate 6-digit reset code]
           ↓
[Store code in ResetCodeSchema (10 min TTL)]
           ↓
[Send code via email with Nodemailer]
           ↓
[Frontend redirects to reset-password]
           ↓
[User enters code + new password]
           ↓
[POST /api/auth/verify-reset-code]
           ↓
[POST /api/auth/reset-password]
           ↓
[Backend validates code and generates new password hash]
           ↓
[Update user document in database]
           ↓
[Delete reset code from collection]
           ↓
[Redirect to login for re-authentication]
```

### 6.2 Widget Control Data Flow

```
┌────────────────────────────────────────────────────────┐
│          Widget Command & Control Data Flow            │
└────────────────────────────────────────────────────────┘

User Interaction → Command Execution:

1. User clicks Toggle Widget button
           ↓
2. JavaScript event handler fires (click event listener)
           ↓
3. Frontend calls: POST /api/command/send
   Payload: { widgetId: "...", command: "ON" }
   Header: { 'x-auth-token': token }
           ↓
4. Backend middleware validates JWT token
           ↓
5. Backend fetches widget from MongoDB (Widget collection)
           ↓
6. Backend fetches user's Adafruit credentials (User collection)
           ↓
7. Backend makes HTTP POST to Adafruit IO API:
   URL: https://io.adafruit.com/api/v2/{adafruitUsername}/feeds/{feedName}/data
   Body: { value: "ON" }
   Auth: ?X-AIO-Key={adafruitApiKey}
           ↓
8. Physical device receives command via Adafruit IO
           ↓
9. Device executes action (e.g., LED turns ON)
           ↓
10. Backend receives response from Adafruit (200 OK)
           ↓
11. Backend updates widget.state.lastValue = "ON"
           ↓
12. Backend increments widget.analytics.successfulCommands
           ↓
13. Backend emits Socket.IO event: 'command-executed'
           ↓
14. All connected clients receive real-time update
           ↓
15. Frontend updates widget visual state immediately
           ↓
16. Toast notification shows success to user
```

### 6.3 Real-Time Update Data Flow

```
┌────────────────────────────────────────────────────────┐
│        Real-Time Sensor Update Data Flow              │
└────────────────────────────────────────────────────────┘

Continuous Sensor Monitoring:

1. Dashboard loads → JavaScript initializes Socket.IO connection
           ↓
2. Socket.IO connects to server via WebSocket
           ↓
3. Server receives connection, creates socket instance
           ↓
4. Frontend initiates periodic sensor fetch via API:
   GET /api/sensors/{widgetId}/data
   (interval: 5-30 seconds based on widget type)
           ↓
5. Backend fetches latest feed value from Adafruit IO:
   GET https://io.adafruit.com/api/v2/{username}/feeds/{feedName}/data/last
           ↓
6. Adafruit returns: { value: "23.5", created_at: "..." }
           ↓
7. Backend stores value in widget.state.lastValue
           ↓
8. Backend sends response to frontend
           ↓
9. Frontend receives new sensor value
           ↓
10. Frontend updates widget display (e.g., "23.5°C")
           ↓
11. If value differs from previous (changed):
    - Emit Socket.IO event: 'feed-data'
    - All connected clients update their display
           ↓
12. Repeat cycle every N seconds until user leaves dashboard
```

### 6.4 Widget State Synchronization

```
┌────────────────────────────────────────────────────────┐
│           Widget Position Sync on Grid                │
└────────────────────────────────────────────────────────┘

Drag-and-Drop Widget Repositioning:

1. User drags widget on Gridstack grid
           ↓
2. Gridstack.js fires 'change' event
           ↓
3. JavaScript captures drag end event
           ↓
4. Extract new position: { x, y, w, h }
           ↓
5. Debounce (wait 500ms) to avoid excessive API calls
           ↓
6. PUT /api/widgets/{widgetId}/position
   Body: { gs: { x: num, y: num, w: num, h: num } }
           ↓
7. Backend validates position values
           ↓
8. Backend updates Widget.gs in MongoDB
           ↓
9. Backend responds with success
           ↓
10. Frontend confirms position persisted
           ↓
11. Next session: Load widgets with saved positions
```

### 6.5 User Data Persistence

```
┌────────────────────────────────────────────────────────┐
│        User Data Storage and Retrieval Flow           │
└────────────────────────────────────────────────────────┘

Data Storage Layers:

┌─ Frontend (Client-Side) ─────────────────────────────┐
│ localStorage:                                       │
│  • token (JWT for auth)                            │
│  • theme preference                                │
│  • temporary UI state                              │
│                                                    │
│ sessionStorage:                                    │
│  • Page state between navigation                   │
│  • Temporary form data                             │
│                                                    │
│ Memory (JavaScript variables):                     │
│  • widgets[] array                                 │
│  • currentUser object                              │
│  • Socket.IO connection                            │
│  • gridStack instance                              │
└────────────────────────────────────────────────────┘
                        ↓
┌─ Backend (Server-Side) ──────────────────────────────┐
│ Express Session:                                    │
│  • req.user (authenticated user)                   │
│  • req.session (session data)                      │
│  • Socket.IO connection tracking                   │
│                                                    │
│ Node.js Memory (Temporary):                        │
│  • Connected Socket.IO clients list                │
│  • Socket emit queues                              │
└────────────────────────────────────────────────────┘
                        ↓
┌─ MongoDB (Persistent Database) ──────────────────────┐
│ Collections:                                        │
│  • users (auth, profiles, settings)                │
│  • widgets (widget configs, state)                 │
│  • terminalmessages (chat history)                 │
│  • sessions (active sessions)                      │
│  • resetcodes (password recovery)                  │
│                                                    │
│ Indexes:                                           │
│  • userId for fast user lookups                    │
│  • email for unique constraint                     │
│  • createdAt for TTL expiration                    │
└────────────────────────────────────────────────────┘
```

### 6.6 API Request/Response Pattern

```
┌────────────────────────────────────────────────────┐
│     Standard API Communication Pattern             │
└────────────────────────────────────────────────────┘

Request:
{
  method: "GET|POST|PUT|DELETE",
  url: "/api/endpoint",
  headers: {
    "Content-Type": "application/json",
    "x-auth-token": localStorage.token
  },
  body: { /* JSON data */ }
}

Response (Success - 200/201):
{
  success: true,
  message: "Operation completed",
  data: { /* Response object */ }
}

Response (Error - 400/401/500):
{
  success: false,
  message: "Error description",
  error: "error-code"
}

Frontend Error Handling:
1. Check response.ok
2. Parse JSON
3. If error: Show toast notification
4. Redirect to login if 401 Unauthorized
5. Show error message from response.message
6. Log detailed error for debugging
```

### 6.7 Form Data Flow (Settings Example)

```
┌────────────────────────────────────────────────────┐
│     Widget Creation Form Data Flow (Settings)     │
└────────────────────────────────────────────────────┘

Form Input:
[User fills widget configuration form]
      ↓
[Form values collected from DOM elements]
      ↓
JavaScript object:
{
  name: "Bedroom Light",
  feedName: "user/feeds/light",
  type: "toggle",
  icon: "fas fa-lightbulb",
  configuration: { onCommand: "ON", offCommand: "OFF", ... },
  appearance: { primaryColor: "#8A2BE2", ... }
}
      ↓
[Validate form data (client-side)]
      ↓
[POST /api/widgets with form data]
      ↓
[Backend validates again (server-side)]
      ↓
[Save to MongoDB Widget collection]
      ↓
[Return widget object with _id to frontend]
      ↓
[Frontend updates configuredList UI]
      ↓
[Show success toast notification]
      ↓
[Widget now appears on dashboard]
      ↓
[Socket.IO broadcasts 'widget-created' event]
      ↓
[All connected clients see new widget]
```

### 6.8 Multi-User Real-Time Sync

```
┌───────────────────────────────────────────────────┐
│    Multi-Client Real-Time Synchronization        │
└───────────────────────────────────────────────────┘

Scenario: Two browsers open for same user

Browser 1:                          Browser 2:
├─ connects to Socket.IO            ├─ connects to Socket.IO
└─ joins room: "user:{userId}"      └─ joins room: "user:{userId}"

Event: User clicks toggle in Browser 1
  ↓
  Backend: 'command-executed'
  ↓
  io.to(`user:${userId}`).emit('widget-updated', {...})
  ↓
  ├─ Browser 1 widget updates ✅
  └─ Browser 2 widget updates ✅

Both browsers see change in real-time!

Note: Each user has isolated room so changes don't broadcast to others
```

---

## Summary

**ControlEx** is a comprehensive IoT control dashboard system that combines:
- **Secure user authentication** (email + Google OAuth + 2FA)
- **Real-time device control** via Adafruit IO integration
- **Flexible widget system** (6 widget types for different control scenarios)
- **Responsive, modern UI** (dark theme with glassmorphism)
- **Persistent data storage** (MongoDB with Mongoose)
- **Real-time updates** (Socket.IO for instant feedback)
- **Account & security management** (preferences, sessions, data export)
- **Production-ready deployment** (Koyeb, Render, traditional hosting)

The architecture follows best practices with separated concerns, proper authentication/authorization, rate limiting, CORS security, and comprehensive error handling. The frontend uses vanilla JavaScript for light footprint while the backend leverages Express.js and MongoDB for scalability.

An AI tool analyzing this documentation should understand:
1. Every page and its purpose
2. All available user actions and workflows
3. How data flows between frontend, backend, and database
4. Security measures in place
5. Real-time update mechanisms
6. Integration with external services (Adafruit, Google)
7. Database schema and relationships
8. All API endpoints and their purposes
