# Paynow MM — Architecture & Operations Guide

---

# Part 1: Operations & Maintenance

## Access Credentials

| Service | URL | Login |
|---------|-----|-------|
| **Admin Dashboard** | https://admin-dashboard-ashen-mu-87.vercel.app | admin@springfield-school.com / Admin@123 |
| **Super Admin** | Same URL | superadmin@paynowmm.com / SuperAdmin@123 |
| **Supabase Dashboard** | https://supabase.com/dashboard/project/quwwkpbiovsaujhtkgzt | Your Supabase account |
| **Firebase Console** | https://console.firebase.google.com/project/canteenpay-a64a1 | arkaraung829@gmail.com |
| **Vercel Dashboard** | https://vercel.com | Your Vercel account |
| **App Store Connect** | https://appstoreconnect.apple.com | Your Apple Developer account |

## Daily Operations

### Adding a New Student
1. Admin Dashboard → Students → Add Student
2. Enter name, grade, section, parent phone/email
3. System auto-generates: student code (STU-YYYY-NNN), QR code (UUID), PIN code (4 digits)
4. Print the student card (QR + PIN) → give to student
5. When parent signs up with matching phone/email → auto-linked

### Depositing Money
1. Admin Dashboard → Students → click "+ Balance" on student row
2. Enter amount (preset 10K/20K/30K/40K or custom)
3. Optional: enter depositor name
4. Click Deposit → balance updated instantly
5. Parent receives push notification

### Processing a Refund
1. Admin Dashboard → Transactions
2. Find the purchase → click "Refund" button
3. Enter reason (optional) → Confirm
4. Balance restored atomically, shown as "refund" type

### Marking Attendance
1. Admin Dashboard → Attendance (or teacher login)
2. Select date + grade + class
3. Click "Mark All Present" → toggle individual students to Absent/Late
4. Click "Save" → parents see it in the app calendar

### Sending Announcements
1. Admin Dashboard → Announcements → New Announcement
2. Enter title + message (English and Myanmar in same field)
3. Select audience (Everyone/Parents/Students)
4. Check "Send Push Notification" → click Send
5. Push notification sent to all matching FCM tokens

### Creating a Teacher Account
1. Admin Dashboard → Teachers → Add Teacher
2. Enter name, email, password, phone
3. Assign grades + classes (multi-select)
4. Teacher logs into same dashboard URL — only sees Attendance tab

### Creating a Seller Account
1. Admin Dashboard → Sellers → Add Seller
2. Enter stall name, email, phone
3. Seller signs up in the app with matching email/phone → auto-linked to stall

## Troubleshooting

### Push Notifications Not Arriving
1. Check parent has FCM token: Supabase → profiles table → fcm_token column
2. If null → parent needs to reopen the app
3. Check webhook fired: Supabase → net._http_response table → latest rows
4. If "No FCM tokens found" → parent not linked or no token
5. If "BadEnvironmentKeyInToken" → parent using debug build, need TestFlight
6. If "UNAUTHENTICATED" → FCM_SERVICE_ACCOUNT secret expired/invalid

### OTP SMS Not Received
1. Firebase Console → Authentication → Settings → SMS Region Policy → must be "Allow by default"
2. Firebase must be on Blaze plan (pay-as-you-go)
3. Check carrier: some Myanmar carriers block Firebase SMS
4. On iOS debug builds: reCAPTCHA always opens (normal — use TestFlight for silent push)
5. Add test phone numbers in Firebase Console for development

### Student QR Not Scanning
1. Check QR format: should be `paynowmm://pay/<UUID>`
2. Check student is_active = true
3. Check seller and student are in the same school
4. If scanner doesn't detect: clean camera lens, ensure good lighting

### Balance Mismatch
1. Check transactions table — every balance change has before/after
2. All mutations go through atomic RPC functions (no direct wallet updates)
3. If mismatch found: compare wallet.balance vs last transaction.balance_after

### Dashboard Slow
1. Students API uses 30s cache for filter data (grades, classes, counts)
2. Cache clears on student create/status change
3. If still slow: check Supabase dashboard for query performance

## Deployment

### Deploy Admin Dashboard
```bash
cd admin-dashboard
npx vercel --yes --prod
```

### Deploy Flutter App to TestFlight
```bash
cd flutter_app
./scripts/deploy_testflight.sh --bump
# Then in Xcode Organizer: Distribute App → TestFlight
```

### Deploy Edge Function
```bash
supabase functions deploy on-transaction --project-ref quwwkpbiovsaujhtkgzt
```

### Run Database Migration
```bash
# Via Supabase Management API:
curl -s -X POST "https://api.supabase.com/v1/projects/quwwkpbiovsaujhtkgzt/database/query" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"query": "<SQL HERE>"}'

# Or paste SQL in Supabase Dashboard → SQL Editor
```

## Environment Variables

### Admin Dashboard (Vercel)
| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side admin key (secret) |
| `FCM_SERVICE_ACCOUNT` | Firebase service account JSON (for announcement push) |

### Edge Function (Supabase Secrets)
| Secret | Purpose |
|--------|---------|
| `FCM_SERVICE_ACCOUNT` | Firebase service account JSON for FCM v1 API |
| `SUPABASE_URL` | Auto-set by Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-set by Supabase |

### Flutter App
| File | Purpose |
|------|---------|
| `canteen_common/lib/config/supabase_config.dart` | Supabase URL + anon key |
| `flutter_app/ios/Runner/GoogleService-Info.plist` | Firebase iOS config |
| `flutter_app/android/app/google-services.json` | Firebase Android config |

## Backup & Recovery

### Database Backup
- Supabase automatically creates daily backups (Pro plan)
- Manual: Supabase Dashboard → Settings → Database → Backups

### Key Data to Never Lose
1. **transactions** table — immutable financial ledger
2. **wallets** table — current balances
3. **students** table — student records + QR codes + PINs
4. **parent_student_links** — parent-child relationships

---

# Part 2: System Architecture

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

## Why Both Firebase AND Supabase?

```
Firebase (GoogleService-Info.plist)      Supabase (supabase_config.dart)
├── Phone OTP (SMS verification)         ├── Database (PostgreSQL)
├── Push Notifications (FCM)             ├── Auth sessions (JWT tokens)
├── Google Sign-In (OAuth)               ├── Realtime (WebSocket)
├── Crashlytics (error reporting)        ├── Row Level Security (RLS)
└── Analytics (usage tracking)           ├── Edge Functions (webhooks)
                                         └── Storage (photos, files)
```

**Why not just Supabase?**
- Supabase's phone auth has poor Myanmar carrier support — Firebase Phone Auth works better
- Supabase has no push notification service — we use Firebase Cloud Messaging (FCM)
- Supabase has no crash reporting — Firebase Crashlytics handles this

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

## Row Level Security (RLS)

RLS = database rules that control who can see/edit which rows. Every query is automatically filtered based on the logged-in user.

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

| Who | Table | Can Do | Rule |
|-----|-------|--------|------|
| Parent | students | SELECT only | Only linked children (via parent_student_links) |
| Parent | wallets | SELECT only | Only linked children's wallets |
| Parent | transactions | SELECT only | Only linked children's transactions |
| Student | students | SELECT only | Only own record (profile_id = auth.uid()) |
| Seller | students | SELECT only | Only students in same school |
| Admin/Staff | ALL tables | Full CRUD | Everything in their school |
| Teacher | attendance | Full CRUD | Only their school |

## Supabase Realtime

Live WebSocket connection — database **pushes** changes instantly, no polling needed.

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
```

| Subscription | Table | Event | Purpose |
|-------------|-------|-------|---------|
| `parent-wallets` | wallets | UPDATE | Balance updates instantly |
| `parent-transactions` | transactions | INSERT | New transactions appear without refresh |
| `chat:{id}` | chat_messages | INSERT | Chat messages appear instantly |

## Supabase Edge Functions

Server-side code for operations the app **can't do directly** (requires secret credentials).

### Complete Edge Function Flow

```
SELLER'S PHONE                    SUPABASE SERVER                     PARENT'S PHONE
─────────────────               ──────────────────                  ─────────────────

Seller scans QR
Enters 500 MMK
Student enters PIN
    │
    ▼
process_purchase()  ──────►  PostgreSQL executes:
                             1. Lock wallet FOR UPDATE
                             2. Check balance ≥ 500
                             3. Check daily limit
                             4. UPDATE wallets SET balance - 500
                             5. INSERT INTO transactions
                                     │
                                     ▼
Seller sees ✓       ◄──────  Return success
(can close app now)                  │
                                     ▼
                             TRIGGER fires automatically:
                             notify_on_transaction()
                                     │
                                     ▼
                             pg_net.http_post() ──► Edge Function
                                                        │
                                                        ▼
                                                   1. Get wallet_id
                                                   2. Find student
                                                   3. Find parents
                                                      (parent_student_links)
                                                   4. Get FCM tokens
                                                      (profiles.fcm_token)
                                                   5. Sign JWT with
                                                      FCM_SERVICE_ACCOUNT
                                                      (SECRET - server only)
                                                   6. POST to FCM API
                                                        │
                                                        ▼
                                                   Firebase Cloud
                                                   Messaging
                                                        │
                                                        ▼
                                                                 ──► Push notification
                                                                     "Purchase: 500 MMK"
                                                                     "Aung Aung spent 500
                                                                      MMK at Canteen.
                                                                      Balance: 9,500 MMK"

                                                   If balance < 2000:
                                                        │
                                                        ▼
                                                                 ──► "Low Balance Alert"
                                                                     "Balance is 1,500 MMK.
                                                                      Please top up."
```

**Why Edge Function (not Flutter app)?**
- FCM service account key is a **secret** — can't be in the app
- Notification must be sent even if the **seller's app closes** after payment
- Database trigger guarantees it runs for **every** transaction

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
    → Success screen → "Scan Next" opens scanner
    → DB trigger → Edge function → FCM push to parent
    → Parent app: realtime balance update + push notification
```

### Notification Flow
```
Transaction INSERT
    → PostgreSQL trigger: notify_on_transaction()
    → pg_net.http_post → Supabase Edge Function
    → Edge function: lookup parents → get FCM tokens → send push
    → Parent: foreground = local notification, background = saved to storage
    → Tap notification → opens notifications screen
```

### Parent Auto-Link Flow
```
Admin creates student with parent_phone or parent_email
    → Parent signs up with matching phone/email
    → auto_link_parent_by_phone/email RPC (SECURITY DEFINER)
    → Creates parent_student_links row
    → Parent sees child on home screen
```

## Project Structure

```
CanteenPay/
├── flutter_app/                  # Unified Flutter app (all roles)
│   ├── lib/
│   │   ├── main.dart             # App entry, Firebase/Supabase init
│   │   ├── router.dart           # GoRouter with role-based routing
│   │   ├── screens/              # auth/, student/, parent/, seller/
│   │   ├── providers/            # State management
│   │   └── widgets/              # Reusable UI components
│   ├── ios/                      # iOS config, APNs, entitlements
│   ├── android/                  # Android config, manifest
│   └── scripts/                  # deploy_testflight.sh
│
├── canteen_common/               # Shared Flutter package
│   └── lib/
│       ├── models/               # Student, Wallet, Transaction, Attendance
│       ├── services/             # Supabase, Notification, Phone Auth
│       ├── providers/            # AuthProvider
│       ├── widgets/              # TransactionTile, BalanceCard
│       └── l10n/                 # English + Myanmar translations
│
├── admin-dashboard/              # Next.js web admin
│   ├── app/dashboard/            # 10 pages
│   ├── app/api/                  # API routes
│   ├── components/               # Sidebar, StatCard
│   └── lib/                      # Supabase client, auth
│
├── database-schema/migrations/   # 001-026 SQL migrations
└── supabase/functions/           # Edge functions
```

## Security Architecture

- **RLS**: 25+ policies — database enforces access per user role
- **Atomic transactions**: PL/pgSQL with `FOR UPDATE` row locks — no race conditions
- **PIN verification**: 4-digit PIN for payments and parent linking
- **Biometric**: Face ID/Touch ID for app unlock
- **Service role key**: server-side only, never in app
- **Anon key**: safe to expose — RLS protects data

## Localization

| Language | Code | Status |
|----------|------|--------|
| English | en | Full |
| Myanmar (Burmese) | my | Full (90+ strings) |

Language toggle on all profile screens.
