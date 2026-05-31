# Paynow MM — System Architecture

## System Overview

```
┌─────────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│  Flutter App     │    │   Supabase Cloud     │    │  Admin Dashboard │
│  (iOS/Android)   │◄──►│   PostgreSQL + RLS   │◄──►│  (Next.js/Vercel)│
│                  │    │   + Realtime          │    │                  │
│  4 Roles:        │    │   + Edge Functions    │    │  10 Pages:       │
│  - Student       │    │   + Auth              │    │  - Dashboard     │
│  - Parent        │    │                       │    │  - Students      │
│  - Seller        │    │  15 Tables            │    │  - Attendance    │
│  - Teacher       │    │  6 RPC Functions      │    │  - Deposits      │
│                  │    │  25+ RLS Policies     │    │  - Transactions  │
│  canteen_common  │    │                       │    │  - Sellers       │
│  (shared pkg)    │    └───────────┬───────────┘    │  - Teachers      │
└─────────────────┘                │                 │  - Reports       │
                                   │                 │  - Chat          │
                          ┌────────▼────────┐        │  - Announcements │
                          │   Firebase      │        │  - Settings      │
                          │   FCM + Auth    │        └──────────────────┘
                          │   + Analytics   │
                          └─────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.10+, Provider, GoRouter |
| Web Admin | Next.js 16, TypeScript, Tailwind CSS |
| Database | Supabase (PostgreSQL + RLS + Realtime) |
| Auth | Supabase Auth + Firebase Phone OTP + Google Sign-In |
| Push Notifications | Firebase Cloud Messaging v1 API |
| Edge Functions | Supabase Edge Functions (Deno) |
| Shared Code | canteen_common Flutter package |
| Deploy | Vercel (dashboard), TestFlight/App Store (mobile) |

## How the Flutter App Connects

The Flutter app connects **directly to Supabase** (no middleware server). Security is enforced by RLS at the database level.

```
Flutter App (anon key + user JWT)
    │
    ├── REST API:   https://quwwkpbiovsaujhtkgzt.supabase.co/rest/v1/...
    ├── Auth:       https://quwwkpbiovsaujhtkgzt.supabase.co/auth/v1/...
    ├── RPC:        https://quwwkpbiovsaujhtkgzt.supabase.co/rest/v1/rpc/...
    ├── Realtime:   wss://quwwkpbiovsaujhtkgzt.supabase.co/realtime/v1/...
    └── Storage:    https://quwwkpbiovsaujhtkgzt.supabase.co/storage/v1/...

Admin Dashboard (service role key — server-side only)
    │
    └── Vercel API Routes ──► Supabase (bypasses RLS)
```

The **anon key** is safe to expose (like a Firebase API key). Every request includes the user's JWT token — Supabase extracts `auth.uid()` and RLS policies filter the data automatically.

## Row Level Security (RLS)

RLS = database rules that control who can see/edit which rows. Every query is automatically filtered based on the logged-in user.

**How it works:**
```
Parent queries: SELECT * FROM students
    ↓
PostgreSQL checks RLS policy:
    "Can this user see this row?"
    ↓
Policy: parent can only see students WHERE EXISTS (
    SELECT 1 FROM parent_student_links
    WHERE student_id = students.id
    AND parent_id = auth.uid()  ← current logged-in user
)
    ↓
Result: only the parent's linked children are returned
(other students are invisible — database blocks them)
```

**Example policies:**

| Who | Table | Can Do | Rule |
|-----|-------|--------|------|
| Parent | students | SELECT only | Only linked children (via parent_student_links) |
| Parent | wallets | SELECT only | Only linked children's wallets |
| Parent | transactions | SELECT only | Only linked children's transactions |
| Parent | attendance | SELECT only | Only linked children's attendance |
| Student | students | SELECT only | Only own record (profile_id = auth.uid()) |
| Seller | students | SELECT only | Only students in same school |
| Admin/Staff | ALL tables | Full CRUD | Everything in their school |
| Teacher | attendance | Full CRUD | Only their school |

**Why this matters:** Even if someone decompiles the app and gets the Supabase URL + anon key, they can ONLY access data their account is allowed to see. The database enforces security, not the app code.

## Supabase Realtime

Realtime = live WebSocket connection. The database **pushes** changes to the app instantly — no polling or pull-to-refresh needed.

```
Parent has app open (WebSocket connected)
    │
    ├── Seller charges student 500 MMK
    │       ↓
    │   wallets table updated (balance: 10000 → 9500)
    │       ↓
    │   Supabase Realtime detects the UPDATE
    │       ↓
    │   Pushes change to parent's WebSocket
    │       ↓
    └── Parent's app updates balance instantly
        (no refresh needed, no API call)
```

**Where we use Realtime:**

| Subscription | Table | Event | Purpose |
|-------------|-------|-------|---------|
| `parent-wallets` | wallets | UPDATE | Balance updates instantly when purchase/deposit happens |
| `parent-transactions` | transactions | INSERT | New transactions appear in activity list without refresh |
| `chat:{conversationId}` | chat_messages | INSERT | Chat messages appear instantly for both sides |

**How it's set up in code:**
```dart
// In children_provider.dart
Supabase.instance.client
    .channel('parent-wallets')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      table: 'wallets',
      callback: (payload) {
        // Update local wallet balance
        final updatedWallet = WalletModel.fromJson(payload.newRecord);
        _wallets[updatedWallet.studentId] = updatedWallet;
        notifyListeners(); // UI rebuilds automatically
      },
    )
    .subscribe();
```

## Supabase Edge Functions

Edge Functions = server-side code running on Supabase's servers (Deno runtime). Used for operations that the Flutter app **can't do directly** — like sending push notifications (requires secret FCM credentials).

```
Transaction INSERT (purchase/deposit/refund)
    │
    ↓
PostgreSQL trigger fires: notify_on_transaction()
    │
    ↓
Trigger calls Edge Function via HTTP (pg_net extension)
    POST https://quwwkpbiovsaujhtkgzt.supabase.co/functions/v1/on-transaction
    │
    ↓
Edge Function (supabase/functions/on-transaction/index.ts):
    │
    ├── 1. Read transaction data from webhook payload
    ├── 2. Look up wallet → student → parent_student_links
    ├── 3. Get parent FCM tokens from profiles table
    ├── 4. Sign JWT with FCM_SERVICE_ACCOUNT (secret)
    ├── 5. Get Google OAuth2 access token
    ├── 6. Call FCM v1 API for each parent device:
    │       POST https://fcm.googleapis.com/v1/projects/canteenpay-a64a1/messages:send
    │       {
    │         "message": {
    │           "token": "parent_fcm_token",
    │           "notification": {
    │             "title": "Purchase: 500 MMK",
    │             "body": "Aung Aung spent 500 MMK at Canteen. Balance: 9,500 MMK"
    │           }
    │         }
    │       }
    │
    └── 7. If balance < 2,000 MMK → send low balance alert too

Parent's phone receives push notification
```

**Why Edge Function (not Flutter app)?**
- FCM service account key is a **secret** — can't be in the app
- The notification must be sent even if the **seller's app closes** after payment
- Database trigger guarantees it runs for **every** transaction

**Current Edge Functions:**

| Function | Trigger | Purpose |
|----------|---------|---------|
| `on-transaction` | INSERT on `transactions` table | Send FCM push notification to linked parents |

**Secrets stored in Edge Function environment:**

| Secret | Purpose |
|--------|---------|
| `FCM_SERVICE_ACCOUNT` | Google service account JSON for FCM v1 API authentication |
| `SUPABASE_URL` | Supabase project URL (auto-set) |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin access to query parent tokens (auto-set) |

## Project Structure

```
CanteenPay/
├── flutter_app/                  # Unified Flutter app (all roles)
│   ├── lib/
│   │   ├── main.dart             # App entry, Firebase/Supabase init
│   │   ├── router.dart           # GoRouter with role-based routing
│   │   ├── screens/
│   │   │   ├── auth/             # Login, onboarding, role select
│   │   │   ├── student/          # QR card, history, profile
│   │   │   ├── parent/           # Children, chat, notifications
│   │   │   ├── seller/           # Scan, payment, sales history
│   │   │   └── shared/           # Edit profile
│   │   ├── providers/            # State management
│   │   ├── widgets/              # Reusable UI components
│   │   └── services/             # Haptic, etc.
│   ├── ios/                      # iOS config, APNs, entitlements
│   ├── android/                  # Android config, manifest
│   └── scripts/                  # deploy_testflight.sh
│
├── canteen_common/               # Shared Flutter package
│   └── lib/
│       ├── models/               # Student, Wallet, Transaction, Attendance
│       ├── services/             # Supabase, Notification, Phone Auth, etc.
│       ├── providers/            # AuthProvider
│       ├── widgets/              # TransactionTile, BalanceCard, etc.
│       ├── l10n/                 # English + Myanmar translations
│       └── config/               # Supabase config
│
├── admin-dashboard/              # Next.js web admin
│   ├── app/
│   │   ├── dashboard/
│   │   │   ├── page.tsx          # Overview stats
│   │   │   ├── students/         # Student management
│   │   │   ├── attendance/       # Mark attendance
│   │   │   ├── deposits/         # Deposit history
│   │   │   ├── transactions/     # All transactions + refund
│   │   │   ├── sellers/          # Seller management
│   │   │   ├── teachers/         # Teacher management
│   │   │   ├── reports/          # Sales reports + charts
│   │   │   ├── chat/             # Parent messaging
│   │   │   ├── announcements/    # School announcements
│   │   │   ├── settings/         # Grades, sections
│   │   │   └── schools/          # Multi-school (super admin)
│   │   └── api/                  # API routes
│   ├── components/               # Sidebar, StatCard, etc.
│   └── lib/                      # Supabase client, auth, utils
│
├── database-schema/
│   └── migrations/               # 001-026 SQL migrations
│
└── supabase/
    └── functions/
        └── on-transaction/       # Push notification edge function
```

## Database Schema (15 Tables)

### Core Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| **schools** | School registry | id, name, name_my, code, address, is_active |
| **profiles** | User accounts | id (FK auth.users), role, school_id, full_name, phone, fcm_token |
| **students** | Student records | id, profile_id, school_id, student_code, qr_data (UUID), pin_code, full_name, grade, class_name, daily_spending_limit |
| **wallets** | Balance per student | id, student_id (unique), balance (BIGINT), is_frozen |
| **transactions** | Immutable ledger | id, wallet_id, type, amount (BIGINT), balance_before, balance_after, description, performed_by, seller_id |
| **canteen_sellers** | Seller stalls | id, profile_id, school_id, stall_name, email, phone |
| **parent_student_links** | Parent-child links | id, parent_id, student_id, relationship |

### Feature Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| **teachers** | Teacher accounts | id, profile_id, school_id, assigned_grades[], assigned_classes[] |
| **attendance** | Daily tracking | id, student_id, school_id, date, status (present/absent/late), marked_by |
| **announcements** | School notices | id, school_id, title, body, target_audience[], is_published |
| **chat_conversations** | Chat threads | id, school_id, parent_id, title, status |
| **chat_messages** | Chat messages | id, conversation_id, sender_id, content, is_read |
| **school_grades** | Grade config | id, school_id, name, display_order |
| **school_sections** | Section config | id, school_id, name, display_order |

### User Roles

| Role | Access | Description |
|------|--------|-------------|
| **student** | App: QR card, history, profile | Shows QR at canteen |
| **parent** | App: children, spending, chat, notifications | Monitors child spending |
| **seller** | App: scan QR, charge, sales history | Operates canteen stall |
| **teacher** | Dashboard: attendance only | Marks daily attendance |
| **admin** | Dashboard: full access | Manages school |
| **counter_staff** | Dashboard: full access | Front desk operations |
| **super_admin** | Dashboard: all schools | Platform administrator |

## Atomic Database Functions

| Function | Purpose | Called By |
|----------|---------|----------|
| **process_purchase** | QR payment with daily limit check, balance deduction | Seller app |
| **admin_process_deposit** | Add balance to student wallet | Admin dashboard |
| **admin_process_refund** | Reverse a purchase transaction | Admin dashboard |
| **auto_link_parent_by_email** | Link parent to student on Google sign-in | Auth flow |
| **auto_link_parent_by_phone** | Link parent to student on OTP sign-in | Auth flow |
| **find_student_by_code** | Search student by code (bypass RLS) | Parent link child |
| **set_daily_spending_limit** | Parent sets child's daily limit | Parent app |

## API Endpoints (Admin Dashboard)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET/POST/PATCH | `/api/students` | CRUD students |
| POST | `/api/students/import` | CSV bulk import |
| GET | `/api/students/export` | CSV export |
| POST | `/api/deposits` | Deposit to wallet |
| POST | `/api/refunds` | Refund transaction |
| GET/POST | `/api/attendance` | Mark/view attendance |
| GET/POST/PATCH | `/api/teachers` | CRUD teachers |
| GET/POST | `/api/chat` | Parent-school messaging |
| GET/POST/DELETE | `/api/announcements` | School announcements |
| GET/POST | `/api/settings/grades` | Grade configuration |
| GET/POST | `/api/settings/sections` | Section configuration |

## Flutter Screens by Role

### Student (`/student`)
| Screen | Purpose |
|--------|---------|
| Home | QR code display, PIN code, balance |
| History | Transaction list with filters |
| Profile | Edit info, language toggle, sign out |

### Parent (`/parent`)
| Screen | Purpose |
|--------|---------|
| Home | Children list with balances, chat button |
| Child Detail | Balance, spending chart, attendance calendar |
| Notifications | Merged activity + announcements list |
| Messages | Chat conversations with school |
| Chat | Individual conversation thread |
| Link Child | Link by student code + PIN |
| Spending Alerts | Set daily limits per child |
| Profile | Edit info, language toggle, sign out |

### Seller (`/seller`)
| Screen | Purpose |
|--------|---------|
| Scan | "Scan Student QR" button, camera scanner |
| Payment Confirm | Enter amount with keypad |
| PIN Verify | Student enters 4-digit PIN to confirm |
| Payment Success | Receipt with "Scan Next" button |
| Sales History | Date-filterable sales list |
| Analytics | Sales charts and trends |
| Profile | Edit info, language toggle, sign out |

### Auth (shared)
| Screen | Purpose |
|--------|---------|
| Onboarding | 3-slide intro (auto-swipe, skip) |
| Login | Phone OTP + Google Sign-In + Face ID |
| Profile Setup | Name + role selection (first login) |

## Key User Flows

### Purchase Flow
```
Seller taps "Scan Student QR"
    → Camera opens
    → Scans student QR (paynowmm://pay/<UUID>)
    → Student info displayed
    → Seller enters amount (keypad + quick amounts)
    → Seller taps "Continue"
    → Student enters 4-digit PIN
    → PIN verified → process_purchase RPC
        → Lock wallet FOR UPDATE
        → Check balance ≥ amount
        → Check daily spending limit
        → Deduct balance
        → Insert transaction
    → Success screen
    → DB trigger fires → Edge function → FCM push to parent
    → Parent app: realtime update + push notification
```

### Deposit Flow
```
Admin opens Students page
    → Clicks "+ Balance" on student row
    → Enters amount (preset: 10K/20K/30K/40K or custom)
    → Optional depositor name
    → Clicks "Deposit"
    → admin_process_deposit RPC (atomic)
    → DB trigger → FCM push to parent
```

### Notification Flow
```
Transaction INSERT
    → PostgreSQL trigger: notify_on_transaction()
    → pg_net.http_post → Supabase Edge Function
    → Edge function:
        → Lookup wallet → student → parent_student_links
        → Get parent FCM tokens from profiles
        → Sign JWT with FCM service account
        → Send FCM v1 API to all parent devices
        → If balance < 2000 MMK → send low balance alert
    → Parent device receives push
    → Foreground: show local notification + save to storage
    → Background: save to storage via background handler
    → Tap: navigate to notifications screen
```

### Parent Auto-Link Flow
```
Admin creates student with parent_phone or parent_email
    → Parent signs up with matching phone/email
    → AuthProvider calls auto_link_parent_by_phone/email RPC
    → SECURITY DEFINER function bypasses RLS
    → Finds matching students
    → Creates parent_student_links rows
    → Parent sees children on home screen
```

## Security Architecture

### Row Level Security (RLS)
- **25+ policies** across all tables
- Staff (admin/counter_staff) have full access to their school
- Parents can only read data for linked children
- Students can only read their own data
- Sellers can read students in their school (for QR scan)
- Teachers can manage attendance for their school

### Authentication
- **Phone OTP**: Firebase Auth → Supabase session
- **Google Sign-In**: Native GoogleSignIn → Supabase signInWithIdToken
- **Face ID/Touch ID**: Biometric lock with session persistence
- **Silent Push**: APNs silent notification for phone verification (no reCAPTCHA)

### Transaction Safety
- All monetary operations use `SECURITY DEFINER` PL/pgSQL functions
- `FOR UPDATE` row locks prevent race conditions
- Atomic: balance update + transaction insert in single DB transaction
- Daily spending limits checked at purchase time

### API Security
- Admin dashboard: `verifyAdmin()` middleware checks Supabase auth token
- Teacher endpoints: `verifyAdminOrTeacher()` allows teacher role
- Service role key: server-side only, never exposed to client
- FCM service account: stored as Supabase Edge Function secret

## Deployment

| Component | Platform | URL |
|-----------|----------|-----|
| Admin Dashboard | Vercel | admin-dashboard-ashen-mu-87.vercel.app |
| Database | Supabase | quwwkpbiovsaujhtkgzt.supabase.co |
| Edge Functions | Supabase | (same project) |
| iOS App | TestFlight → App Store | com.canteenpay.canteenPay |
| Firebase | Firebase Console | canteenpay-a64a1 |

## Build Commands

```bash
# Flutter app
cd flutter_app
flutter pub get && flutter run

# TestFlight build
./scripts/deploy_testflight.sh --bump

# Admin dashboard
cd admin-dashboard
npm install && npm run dev         # Development
npx vercel --prod                  # Deploy

# Database migrations
# Run in Supabase SQL Editor (001-026)
```

## Localization

| Language | Code | Status |
|----------|------|--------|
| English | en | Full |
| Myanmar (Burmese) | my | Full (90+ strings) |

Language toggle available on all profile screens.
