# CanteenPay - School Cashless Payment System

## Project Structure
- `flutter_app/` - Unified Flutter app with role-based routing (student/parent/seller)
- `canteen_common/` - Shared Flutter package (models, services, providers, widgets, l10n)
- `admin-dashboard/` - Next.js web admin (student management, deposits, reports)
- `database-schema/migrations/` - PostgreSQL migrations for Supabase
- `supabase/functions/` - Edge functions (push notifications)

Legacy separate apps (superseded by flutter_app/):
- `flutter_seller_app/`, `flutter_parent_app/`, `flutter_student_app/`

## Tech Stack
- **Mobile**: Flutter 3.10+, Provider state management, GoRouter navigation
- **Web Admin**: Next.js 16, TypeScript, Tailwind CSS
- **Database**: Supabase (PostgreSQL with RLS, Realtime)
- **Auth**: Supabase Auth
- **Notifications**: Firebase Cloud Messaging
- **QR**: qr_flutter (generate), mobile_scanner (scan)

## Key Architecture Decisions
- Single Flutter app with role-based routing (student/parent/seller flows)
- BIGINT for all monetary values (smallest currency unit - kyats)
- Atomic Postgres functions for balance mutations (process_purchase, process_deposit)
- QR data is a random UUID, separate from human-readable student code
- Shared canteen_common package for models, services, auth

## Build Commands
```bash
# Shared package
cd canteen_common && flutter pub get

# Unified Flutter app
cd flutter_app && flutter pub get && flutter run

# Admin dashboard
cd admin-dashboard && npm install && npm run dev
```

## Database
Run migrations in order from `database-schema/migrations/001_*.sql` through `012_*.sql` in your Supabase SQL editor.
