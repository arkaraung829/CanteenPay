/// Canteen Common Package
///
/// Shared code library for all CanteenPay Flutter applications.
///
/// This package contains:
/// - Shared configuration (API endpoints, Supabase config, theme)
/// - Shared models (User, Student, Wallet, Transaction, etc.)
/// - Shared providers (Auth, SafeChangeNotifier)
/// - Shared services (Supabase RPC, notifications, connectivity)
/// - Shared utilities (currency formatting, exceptions)
/// - Shared widgets (balance card, transaction tile, loading, empty state)
///
/// Usage:
/// ```dart
/// import 'package:canteen_common/canteen_common.dart';
///
/// // Services
/// final supabaseService = SupabaseService.instance;
///
/// // Models
/// final user = UserModel.fromJson(json);
///
/// // Widgets
/// BalanceCard(wallet: wallet);
/// ```
library canteen_common;

// ============================================================================
// CONFIG
// ============================================================================

export 'config/api_config.dart';
export 'config/supabase_config.dart';
export 'config/app_theme.dart';

// ============================================================================
// MODELS
// ============================================================================

export 'models/user_model.dart';
export 'models/school_model.dart';
export 'models/student_model.dart';
export 'models/wallet_model.dart';
export 'models/transaction_model.dart';
export 'models/seller_model.dart';
export 'models/announcement_model.dart';
export 'models/parent_student_link_model.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

export 'providers/safe_change_notifier.dart';
export 'providers/auth_provider.dart';

// ============================================================================
// SERVICES
// ============================================================================

export 'services/supabase_service.dart';
export 'services/notification_service.dart';
export 'services/notification_storage_service.dart';
export 'services/connectivity_service.dart';
export 'services/logging_service.dart';
export 'services/crash_reporting_service.dart';
export 'services/analytics_service.dart';
export 'services/security_service.dart';
export 'services/biometric_service.dart';
export 'services/session_service.dart';
export 'services/offline_cache_service.dart';
export 'services/offline_action_queue.dart';
export 'services/rate_limiter.dart';
export 'services/error_handler_service.dart';
export 'services/device_id_service.dart';
export 'services/phone_auth_service.dart';
export 'services/secure_storage_service.dart';

// ============================================================================
// UTILS
// ============================================================================

export 'utils/currency_formatter.dart';
export 'utils/exceptions.dart';

// ============================================================================
// WIDGETS
// ============================================================================

export 'widgets/balance_card.dart';
export 'widgets/transaction_tile.dart';
export 'widgets/loading_overlay.dart';
export 'widgets/empty_state_widget.dart';
