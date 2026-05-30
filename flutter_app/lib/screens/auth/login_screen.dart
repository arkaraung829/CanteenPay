import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../services/haptic_service.dart';
import '../../widgets/error_card.dart';

enum _AuthStep { phone, otp, profile, emailLogin }

/// Key for storing biometric preference
const _kBiometricEnabled = 'biometric_login_enabled';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  String _role = 'parent';
  _AuthStep _step = _AuthStep.phone;
  bool _obscurePassword = true;
  PhoneCountry _selectedCountry = PhoneAuthService.defaultCountry;
  int _resendCooldown = 0;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  bool _checkingBiometric = true;
  String _biometricType = 'face'; // 'face' or 'fingerprint'

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Try biometric login on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricLogin());
  }

  Future<void> _tryBiometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool(_kBiometricEnabled) ?? false;

      if (!biometricEnabled) {
        setState(() => _checkingBiometric = false);
        return;
      }

      // Check if there's an existing session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() => _checkingBiometric = false);
        return;
      }

      // Device supports biometric?
      final biometric = BiometricService();
      if (!await biometric.isAvailable()) {
        setState(() => _checkingBiometric = false);
        return;
      }

      // Prompt Face ID / Touch ID
      final type = await biometric.getBiometricType();
      final reason = type == 'face'
          ? 'Unlock Paynow MM with Face ID'
          : 'Unlock Paynow MM with fingerprint';

      setState(() => _biometricType = type);

      final authenticated = await biometric.authenticate(reason: reason);

      if (authenticated && mounted) {
        HapticService.success();
        // Wait for AuthProvider to load profile before revealing UI
        final auth = context.read<AuthProvider>();
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (auth.isAuthenticated && auth.user != null) {
            return;
          }
        }
      } else if (!authenticated && mounted) {
        // Biometric cancelled or failed — sign out so the router doesn't
        // auto-redirect away from the login screen.
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      // Biometric error — also sign out to prevent auto-login
      if (mounted) {
        try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
      }
    }

    if (mounted) setState(() => _checkingBiometric = false);
  }

  /// Enable biometric for future logins
  static Future<void> enableBiometric() async {
    final biometric = BiometricService();
    if (await biometric.isAvailable()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBiometricEnabled, true);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  String get _rawPhone => _phoneController.text.trim();

  void _startResendCooldown() {
    _resendCooldown = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  Future<void> _sendOtp() async {
    HapticService.selection();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 7) {
      _showError('Please enter a valid phone number');
      _shake();
      return;
    }

    // Switch to OTP step immediately -- reCAPTCHA may send app to background
    _otpController.clear();
    setState(() => _step = _AuthStep.otp);
    _startResendCooldown();

    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithPhone(_rawPhone, country: _selectedCountry);
    if (mounted) {
      if (success) {
        HapticService.success();
        // Show success snackbar like cuckoo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to ${PhoneAuthService().formatPhone(_rawPhone, _selectedCountry)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        // Auto-focus OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
      // Don't revert to phone step on failure -- OTP may have been sent
      // via reCAPTCHA flow. User can tap "Change Number" to go back.
      auth.clearError();
    }
  }

  Future<void> _verifyOtp() async {
    _dismissKeyboard();
    HapticService.medium();
    final code = _otpController.text.trim();
    if (code.length < 6) return; // Wait for 6 digits

    HapticFeedback.lightImpact();

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(
      _rawPhone,
      code,
      fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      role: _role,
      country: _selectedCountry,
    );
    if (mounted) {
      if (success) {
        HapticService.success();
        await enableBiometric();
        if (auth.user?.fullName == null || auth.user!.fullName!.isEmpty) {
          setState(() => _step = _AuthStep.profile);
        }
      } else {
        _shake();
      }
    }
  }

  void _shake() {
    HapticService.error();
    _shakeController.forward(from: 0);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // No keyboard tracking needed — resizeToAvoidBottomInset handles it

    // Show biometric check screen
    if (_checkingBiometric) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primary, Color(0xFF0D47A1)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.restaurant_rounded, size: 44, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                Icon(
                  _biometricType == 'face' ? Icons.face_rounded : Icons.fingerprint_rounded,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  _biometricType == 'face' ? 'Verifying with Face ID...' : 'Verifying with fingerprint...',
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.deferToChild,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primary, Color(0xFF0D47A1)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  children: [
                    // Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.restaurant_rounded, size: 36, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Paynow MM',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'School Cashless Payment',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 28),

                    // Form card — only phone/OTP/profile content
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(offset: Offset(_shakeAnimation.value, 0), child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _buildCurrentStep(auth),
                      ),
                    ),

                    // Google sign-in — outside card, only on phone step
                    if (_step == _AuthStep.phone) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: auth.isLoading ? null : () async {
                            HapticService.selection();
                            final success = await auth.signInWithGoogle();
                            if (mounted && success) {
                              HapticService.success();
                              await enableBiometric();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata, size: 22, color: Colors.white.withValues(alpha: 0.9)),
                              const SizedBox(width: 8),
                              Text(
                                'Continue with Google',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Text(
                      'Contact your school admin for access',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AuthProvider auth) {
    switch (_step) {
      case _AuthStep.phone:
        return _buildPhoneStep(auth);
      case _AuthStep.otp:
        return _buildOtpStep(auth);
      case _AuthStep.profile:
        return _buildProfileStep(auth);
      case _AuthStep.emailLogin:
        return _buildEmailStep(auth);
    }
  }

  // --- Step 1: Phone Number ---

  Widget _buildPhoneStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Sign in to continue', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),

        if (auth.error != null) ...[
          ErrorCard(message: auth.error!, onDismiss: () => auth.clearError()),
          const SizedBox(height: 12),
        ],

        // Phone input: flag button + phone field in one row
        Row(
          children: [
            // Country flag button
            GestureDetector(
              onTap: () {
                HapticService.light();
                final idx = PhoneAuthService.supportedCountries.indexOf(_selectedCountry);
                setState(() {
                  _selectedCountry = PhoneAuthService.supportedCountries[(idx + 1) % PhoneAuthService.supportedCountries.length];
                  _phoneController.clear();
                });
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[500]),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Phone number field
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendOtp(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
                ],
                style: const TextStyle(fontSize: 17, letterSpacing: 1),
                decoration: InputDecoration(
                  hintText: _selectedCountry.placeholder,
                  hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 0),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(_selectedCountry.dialCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Send OTP button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Send OTP Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // --- Step 2: OTP Verification ---

  Widget _buildOtpStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle with phone number
        Text(
          'We sent a 6-digit code to\n${PhoneAuthService().formatPhone(_phoneController.text, _selectedCountry)}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Error
        if (auth.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Loading indicator when verifying
        if (auth.isLoading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                  SizedBox(width: 10),
                  Text('Verifying...', style: TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // OTP input -- cuckoo style: centered, large font, 28px, letterSpacing 16
        TextFormField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          autofocus: true,
          enabled: !auth.isLoading,
          onFieldSubmitted: (_) => _verifyOtp(),
          onChanged: (value) {
            setState(() {}); // Update UI
            // Auto-submit when 6 digits entered
            if (value.length == 6 && !auth.isLoading) {
              _verifyOtp();
            }
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(
              fontSize: 28,
              letterSpacing: 16,
              color: Colors.grey[300],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
        ),

        const SizedBox(height: 16),

        // Resend OTP row (cuckoo style)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (_resendCooldown > 0)
              Text(
                '${_resendCooldown}s',
                style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
              )
            else
              TextButton(
                onPressed: auth.isLoading ? null : () {
                  HapticService.light();
                  _sendOtp();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('or', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 12),

        // Google Sign-In fallback
        GestureDetector(
          onTap: auth.isLoading ? null : () async {
            HapticService.selection();
            final success = await auth.signInWithGoogle();
            if (mounted && success) {
              HapticService.success();
              await enableBiometric();
            }
          },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.g_mobiledata, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Sign in with Google instead', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Change phone number
        Center(
          child: GestureDetector(
            onTap: () {
              HapticService.light();
              auth.clearError();
              _otpController.clear();
              setState(() => _step = _AuthStep.phone);
            },
            child: Text('Change Phone Number', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
        ),
      ],
    );
  }

  // --- Step 3: Profile Setup (first time only) ---

  Widget _buildProfileStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Set Up Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Tell us about yourself', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),

        _field(_nameController, 'Full Name', Icons.person_rounded, textCap: TextCapitalization.words, autofocus: true),
        const SizedBox(height: 16),

        const Text('I am a...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _roleChip('parent', 'Parent', Icons.family_restroom_rounded),
            const SizedBox(width: 8),
            _roleChip('student', 'Student', Icons.school_rounded),
            const SizedBox(width: 8),
            _roleChip('seller', 'Seller', Icons.storefront_rounded),
          ],
        ),
      ],
    );
  }

  // --- Email Login (backup) ---

  Widget _buildEmailStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () { auth.clearError(); setState(() => _step = _AuthStep.phone); },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Email Login', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Sign in with email and password', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),

        if (auth.error != null) ...[
          ErrorCard(message: auth.error!, onDismiss: () => auth.clearError()),
          const SizedBox(height: 12),
        ],

        _field(_emailController, 'Email', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _field(
          _passwordController, 'Password', Icons.lock_rounded,
          obscureText: _obscurePassword,
          suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppTheme.textHint),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _showForgotPassword(context),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPassword(BuildContext context) {
    final resetController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email and we\'ll send a password reset link.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_rounded, size: 20),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetController.text.trim();
              if (email.isEmpty) return;
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset link sent! Check your email.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  // --- Reusable widgets ---

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    TextCapitalization textCap = TextCapitalization.none,
    bool autofocus = false,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCap,
      autofocus: autofocus,
      textInputAction: textInputAction ?? TextInputAction.next,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      ),
    );
  }

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticService.light(); setState(() => _role = value); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppTheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? AppTheme.primary : AppTheme.textHint),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppTheme.primary : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

}
