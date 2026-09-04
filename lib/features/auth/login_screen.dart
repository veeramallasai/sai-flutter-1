import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_routes.dart';
import '../../core/auth/local_auth_session.dart';
import '../../core/network/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _deepGreen = Color(0xFF1B5E20);
  static const Color _background = Color(0xFFF9FAF9);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF666666);
  static const Color _border = Color(0xFFE0E3E0);
  static const Color _error = Color(0xFFD32F2F);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _identifierFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _loading = false;
  String? _socialLoading;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    return digits;
  }

  String? _validateIdentifier(String? value) {
    final String input = value?.trim() ?? '';
    if (input.isEmpty) return 'Enter your email or mobile number';

    if (input.contains('@')) {
      final RegExp email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!email.hasMatch(input)) return 'Enter a valid email address';
      return null;
    }

    final String phone = _normalizePhone(input);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Enter your password';
    if (password.length < 8) return 'Password must contain at least 8 characters';
    return null;
  }

  Future<String> _emailForIdentifier(String identifier) async {
    final String input = identifier.trim();
    if (input.contains('@')) return input.toLowerCase();

    final String phone = _normalizePhone(input);
    QuerySnapshot<Map<String, dynamic>> result = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: '+91$phone')
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      result = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
    }

    if (result.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account was found for this mobile number.',
      );
    }

    final String email = (result.docs.first.data()['email'] ?? '').toString().trim();
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'This mobile number is not linked to an email account.',
      );
    }
    return email.toLowerCase();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String identifier = _identifierController.text.trim();
    if (!identifier.contains('@')) {
      _showError('For Phase-1 backend login, please use your email address.');
      return;
    }

    setState(() {
      _loading = true;
      _socialLoading = null;
    });

    try {
      final response = await ApiClient().post(
        '/api/v1/auth/login',
        body: <String, dynamic>{
          'email': identifier.toLowerCase(),
          'password': _passwordController.text,
        },
      );
      final dynamic raw = response.data;
      if (raw is! Map) throw StateError('Invalid login response.');
      final Map<String, dynamic> data = raw.map(
        (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
      );
      await LocalAuthSession.saveFromAuthResponse(data);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (error) {
      if (mounted) _showError('Unable to login. Please check your credentials or server connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _showPasswordSetupDialog() async {
    final String initialEmail = _identifierController.text.trim().contains('@')
        ? _identifierController.text.trim().toLowerCase()
        : '';
    final emailController = TextEditingController(text: initialEmail);
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool otpSent = false;
    bool busy = false;
    String? status;

    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> sendOtp() async {
              final email = emailController.text.trim().toLowerCase();
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                setDialogState(() => status = 'Enter a valid email address.');
                return;
              }
              setDialogState(() { busy = true; status = null; });
              try {
                final response = await ApiClient().post(
                  '/api/v1/auth/password-setup/send',
                  body: <String, dynamic>{'email': email},
                );
                setDialogState(() {
                  otpSent = true;
                  status = response.message.isNotEmpty
                      ? response.message
                      : 'OTP sent. Check your Gmail inbox.';
                });
              } catch (e) {
                String errorMsg = 'Unable to send OTP. Check backend SMTP settings.';
                if (e is NetworkException) {
                  errorMsg = e.message;
                }
                setDialogState(() => status = errorMsg);
              } finally {
                setDialogState(() => busy = false);
              }
            }

            Future<void> verifyAndSetPassword() async {
              final email = emailController.text.trim().toLowerCase();
              final otp = otpController.text.trim();
              final password = newPasswordController.text;
              if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                setDialogState(() => status = 'Enter the 6-digit OTP from Gmail.');
                return;
              }
              if (password.length < 8) {
                setDialogState(() => status = 'New password must be at least 8 characters.');
                return;
              }
              setDialogState(() { busy = true; status = null; });
              try {
                final response = await ApiClient().post(
                  '/api/v1/auth/password-setup/complete',
                  body: <String, dynamic>{
                    'email': email,
                    'otp': otp,
                    'password': password,
                  },
                );

                String token = '';
                Map<String, dynamic> authData = <String, dynamic>{};

                if (response.data is Map) {
                  authData = (response.data as Map).map(
                    (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v),
                  );
                  token = (authData['accessToken'] ?? authData['token'] ?? '').toString().trim();
                }

                // If backend completed password setup without returning token directly, auto-login
                if (token.isEmpty) {
                  try {
                    final loginResponse = await ApiClient().post(
                      '/api/v1/auth/login',
                      body: <String, dynamic>{
                        'email': email,
                        'password': password,
                      },
                    );
                    if (loginResponse.data is Map) {
                      authData = (loginResponse.data as Map).map(
                        (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v),
                      );
                      token = (authData['accessToken'] ?? authData['token'] ?? '').toString().trim();
                    }
                  } catch (_) {
                    // Auto-login optional; fallback to manual login below
                  }
                }

                _identifierController.text = email;
                _passwordController.text = password;

                if (!mounted) return;
                Navigator.of(dialogContext).pop();

                if (token.isNotEmpty) {
                  await LocalAuthSession.saveFromAuthResponse(authData);
                  if (mounted) {
                    Navigator.of(this.context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated successfully! Please click Login to continue.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                }
              } catch (e) {
                String errorMsg = 'OTP verification/password setup failed. Check OTP and try again.';
                if (e is NetworkException) {
                  errorMsg = e.message;
                }
                setDialogState(() => status = errorMsg);
              } finally {
                if (dialogContext.mounted) setDialogState(() => busy = false);
              }
            }

            return AlertDialog(
              title: const Text('Set password with Email OTP'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('We will send a 6-digit OTP to your Gmail through the Farm To Home backend.'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        enabled: !busy && !otpSent,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                      ),
                      if (otpSent) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: otpController,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(labelText: '6-digit OTP', prefixIcon: Icon(Icons.password_rounded)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: newPasswordController,
                          enabled: !busy,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                        ),
                      ],
                      if (status != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(status!, style: TextStyle(color: status!.toLowerCase().contains('sent') ? _deepGreen : _error, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: busy ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                if (!otpSent)
                  FilledButton(onPressed: busy ? null : sendOtp, child: Text(busy ? 'Sending...' : 'Send OTP'))
                else ...<Widget>[
                  TextButton(onPressed: busy ? null : sendOtp, child: const Text('Resend OTP')),
                  FilledButton(onPressed: busy ? null : verifyAndSetPassword, child: Text(busy ? 'Verifying...' : 'Verify & Login')),
                ],
              ],
            );
          },
        );
      },
    );
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
  }

  Future<void> _continueWithGoogle() async {
    _showError('Google sign-in is disabled while Firebase is being removed. Use email login.');
  }

  Future<void> _continueWithApple() async {
    _showError('Apple sign-in is disabled while Firebase is being removed. Use email login.');
  }

  Future<void> _completeSocialSignIn(UserCredential credential) async {
    final User? user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'social-login-failed');
    }

    final DocumentReference<Map<String, dynamic>> ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();

    final List<String> names = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
    final String firstName = names.isNotEmpty && names.first.isNotEmpty ? names.first : '';
    final String lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

    final Map<String, dynamic> profile = <String, dynamic>{
      'uid': user.uid,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'photoUrl': user.photoURL ?? '',
      'phoneVerified': user.phoneNumber?.isNotEmpty == true,
      'shoppingMode': existing.data()?['shoppingMode'] ?? 'home',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      profile['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(profile, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return error.message ?? 'No account was found with these details.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email/mobile number or password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'popup-closed-by-user':
        return 'Sign in was cancelled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _error,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _LoginBackground(),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 28,
                vertical: compact ? 18 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: compact ? _compactLayout() : _desktopLayout(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLayout() {
    return Column(
      children: <Widget>[
        const _BrandHeader(),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white70),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 34,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: _form(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopLayout() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: Container(
        constraints: const BoxConstraints(minHeight: 700),
        decoration: const BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 60,
              offset: Offset(0, 24),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Expanded(
                flex: 11,
                child: _BrandPanel(),
              ),
              Expanded(
                flex: 10,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE8F5E9),
                        width: 5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(42),
                  child: _form(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Welcome back',
              style: TextStyle(
                color: _text,
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Sign in to continue shopping fresh products from trusted farms.',
              style: TextStyle(
                color: _muted,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.verified_user_outlined, color: _green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secure sign-in • Your account stays protected',
                      style: TextStyle(
                        color: _deepGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _identifierController,
              focusNode: _identifierFocus,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(100),
              ],
              validator: _validateIdentifier,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Email or phone number',
                hintText: 'name@example.com or 98765 43210',
                prefixIcon: Icon(Icons.person_outline_rounded, color: _green),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !_loading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              validator: _validatePassword,
              onFieldSubmitted: (_) {
                if (!_loading) _login();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: _green),
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _showPasswordSetupDialog,
                child: const Text(
                  'Set / Forgot password with OTP',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading && _socialLoading == null
                    ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
                    : const Text(
                  'LOGIN',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              children: <Widget>[
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
            _SocialButton(
              enabled: !_loading,
              onPressed: _continueWithGoogle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_socialLoading == 'google')
                    const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  else
                    Image.asset(
                      'assets/icons/google logo.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 28,
                      ),
                    ),
                  const SizedBox(width: 11),
                  const Text('Continue with Google'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SocialButton(
              enabled: !_loading,
              onPressed: _continueWithApple,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_socialLoading == 'apple')
                    const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  else
                    const Icon(Icons.apple, size: 23, color: Colors.black),
                  const SizedBox(width: 11),
                  const Text('Continue with Apple'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text(
                  'New to Farm To Home?',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pushNamed(AppRoutes.register),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: _LoginScreenState._text,
          side: const BorderSide(color: _LoginScreenState._border),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x260B7A3E),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: _LoginScreenState._green,
            size: 50,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'FARM TO HOME',
          style: TextStyle(
            color: _LoginScreenState._deepGreen,
            fontSize: 22,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Fresh • Organic • Trusted',
          style: TextStyle(
            color: _LoginScreenState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(46),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF43A047),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.eco_rounded, color: Colors.white, size: 44),
              SizedBox(width: 12),
              Text(
                'FARM TO HOME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          SizedBox(height: 72),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Color(0x22FFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(999)),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0x44FFFFFF)),
              ),
            ),
            child: Text(
              'FARM FRESH  •  SECURE  •  FAST',
              style: TextStyle(
                color: Color(0xFFFFE082),
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Freshness\nstarts at the farm.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Retail for homes. Bulk units for shop owners. Quick, scheduled and pre-order delivery in one premium experience.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 28),
          _Feature(icon: Icons.eco_outlined, text: 'Farm-direct products'),
          SizedBox(height: 14),
          _Feature(icon: Icons.storefront_outlined, text: 'Home & Shop Owner modes'),
          SizedBox(height: 14),
          _Feature(icon: Icons.local_shipping_outlined, text: 'Flexible delivery options'),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE9F7EE),
            Color(0xFFFFFBF3),
            _LoginScreenState._background,
          ],
        ),
      ),
    );
  }
}
