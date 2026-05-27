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
  final _otpFocusNode = FocusNode();
  final _scrollController = ScrollController();
  String _role = 'parent';
  _AuthStep _step = _AuthStep.phone;
  bool _obscurePassword = true;
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
          ? 'Unlock CanteenPay with Face ID'
          : 'Unlock CanteenPay with fingerprint';

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
      }
    } catch (_) {}

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
    _otpFocusNode.dispose();
    _scrollController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String get _formattedPhone {
    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = '+95${phone.substring(1)}';
    if (!phone.startsWith('+')) phone = '+95$phone';
    return phone;
  }

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

    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithPhone(_formattedPhone);
    if (mounted) {
      if (success) {
        HapticService.success();
        _otpController.clear();
        setState(() => _step = _AuthStep.otp);
        _startResendCooldown();
        // Show green snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $_formattedPhone'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        // Auto-focus OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      } else {
        _shake();
      }
    }
  }

  Future<void> _verifyOtp() async {
    HapticService.selection();
    final code = _otpController.text.trim();
    if (code.length < 6) {
      _showError('Please enter the 6-digit code');
      _shake();
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(
      _formattedPhone,
      code,
      fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      role: _role,
    );
    if (mounted) {
      if (success) {
        HapticService.success();
        await enableBiometric(); // Enable Face ID for next login
        // Check if profile has a name — if not, show profile step
        if (auth.user?.fullName == null || auth.user!.fullName!.isEmpty) {
          setState(() => _step = _AuthStep.profile);
        }
        // Otherwise router auto-redirects
      } else {
        _shake();
      }
    }
  }

  Future<void> _saveProfile() async {
    HapticService.selection();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      _shake();
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Update profiles table
      await supabase.from('profiles').update({
        'full_name': name,
        'role': _role,
      }).eq('id', userId);

      // Update auth metadata
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': name, 'role': _role}),
      );

      // Reload profile in AuthProvider
      if (mounted) {
        final auth = context.read<AuthProvider>();
        await auth.reloadProfile();
        HapticService.success();
      }
    } catch (e) {
      _showError('Failed to save profile');
    }
  }

  Future<void> _emailLogin() async {
    HapticService.selection();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in email and password');
      _shake();
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithEmail(email, password);
    if (mounted) {
      if (success) {
        await enableBiometric();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
      onTap: () => FocusScope.of(context).unfocus(),
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
          child: Builder(
            builder: (context) {
              final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 100;
              if (keyboardVisible) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients && mounted) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: keyboardVisible ? 8 : 24),

                  // Logo — shrinks when keyboard is visible
                  if (!keyboardVisible) TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.restaurant_rounded, size: 44, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CanteenPay',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'School Cashless Payment',
                          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: keyboardVisible ? 12 : 36),

                  // Form card
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(offset: Offset(_shakeAnimation.value, 0), child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _buildCurrentStep(auth),
                    ),
                  ),

                  if (!keyboardVisible) ...[
                  const SizedBox(height: 24),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow(Icons.qr_code_scanner_rounded, 'Students scan QR at canteen'),
                        const SizedBox(height: 8),
                        _infoRow(Icons.account_balance_wallet_rounded, 'Parents track spending in real-time'),
                        const SizedBox(height: 8),
                        _infoRow(Icons.security_rounded, 'Secure cashless payments'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Contact your school admin for access',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Action button pinned above keyboard
                _buildBottomButton(auth, keyboardVisible),
              ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBottomButton(AuthProvider auth, bool keyboardVisible) {
    if (!keyboardVisible || _checkingBiometric) return const SizedBox.shrink();

    // Show contextual button based on current step
    String label;
    VoidCallback? onPressed;

    switch (_step) {
      case _AuthStep.phone:
        label = 'Send OTP Code';
        onPressed = auth.isLoading ? null : _sendOtp;
      case _AuthStep.otp:
        label = 'Verify & Sign In';
        onPressed = auth.isLoading ? null : _verifyOtp;
      case _AuthStep.profile:
        label = 'Get Started';
        onPressed = auth.isLoading ? null : _saveProfile;
      case _AuthStep.emailLogin:
        label = 'Sign In';
        onPressed = auth.isLoading ? null : _emailLogin;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF0D47A1).withValues(alpha: 0.0), const Color(0xFF0D47A1)],
        ),
      ),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: auth.isLoading
              ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  // ─── Step 1: Phone Number ───

  Widget _buildPhoneStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Enter your phone number to get started', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),

        if (auth.error != null) ...[
          ErrorCard(message: auth.error!, onDismiss: () => auth.clearError()),
          const SizedBox(height: 12),
        ],

        // Phone input
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendOtp(),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (_scrollController.hasClients && mounted) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
          maxLength: 11,
          autofocus: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
          decoration: InputDecoration(
            counterText: '',
            labelText: 'Phone Number',
            hintText: '09xxxxxxxxx',
            labelStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
            prefixIcon: Container(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇲🇲', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+95', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                ],
              ),
            ),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 20),

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

        const SizedBox(height: 20),

        // Email login option
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Have email login? ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            GestureDetector(
              onTap: () {
                HapticService.light();
                auth.clearError();
                setState(() => _step = _AuthStep.emailLogin);
              },
              child: const Text('Use Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: OTP Verification ───

  Widget _buildOtpStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () { auth.clearError(); setState(() => _step = _AuthStep.phone); },
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Verify Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit code sent to ${_phoneController.text}',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        if (auth.error != null) ...[
          ErrorCard(message: auth.error!, onDismiss: () => auth.clearError()),
          const SizedBox(height: 12),
        ],

        // OTP input
        TextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: TextStyle(fontSize: 28, letterSpacing: 12, color: Colors.grey[300]),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
          autofocus: true,
          onChanged: (value) {
            if (value.length == 6 && !auth.isLoading) {
              _verifyOtp();
            }
          },
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Verify & Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 16),

        // Resend code with cooldown
        Center(
          child: _resendCooldown > 0
              ? Text(
                  'Resend code in ${_resendCooldown}s',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                )
              : GestureDetector(
                  onTap: auth.isLoading ? null : _sendOtp,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      children: [
                        TextSpan(text: "Didn't receive the code? "),
                        TextSpan(
                          text: 'Resend',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 12),

        // Change phone number
        Center(
          child: GestureDetector(
            onTap: () {
              auth.clearError();
              setState(() => _step = _AuthStep.phone);
            },
            child: const Text(
              'Change Phone Number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Profile Setup (first time only) ───

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
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Email Login (backup) ───

  Widget _buildEmailStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () { auth.clearError(); setState(() => _step = _AuthStep.phone); },
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
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
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _emailLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Reusable widgets ───

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

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)))),
      ],
    );
  }
}
