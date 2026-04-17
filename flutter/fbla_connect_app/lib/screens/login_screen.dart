import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';

/// Sign-in screen using Supabase email + password auth.
/// Redesigned for visual impact: staggered entrance animations, gold CTA,
/// clean minimal inputs with electric blue focus states.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey              = GlobalKey<FormState>();
  final _emailController      = TextEditingController();
  final _passwordController   = TextEditingController();

  bool    _loading              = false;
  bool    _obscurePassword      = true;
  String? _errorMessage;
  bool    _emailUnconfirmed     = false;
  bool    _resendingVerification = false;
  String? _devVerifyCode;

  late AnimationController _enterCtrl;
  late List<Animation<double>> _staggeredOpacity;
  late List<Animation<Offset>> _staggeredSlide;

  @override
  void initState() {
    super.initState();
    _setupEntranceAnimations();
  }

  void _setupEntranceAnimations() {
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    const staggerMs = 60.0;
    const totalItems = 5; // title, subtitle, email, password, button

    _staggeredOpacity = List.generate(totalItems, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(
            i * staggerMs / 1200,
            (i * staggerMs / 1200) + 0.4,
            curve: FblaMotion.strongEaseOut,
          ),
        ),
      );
    });

    _staggeredSlide = List.generate(totalItems, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(
            i * staggerMs / 1200,
            (i * staggerMs / 1200) + 0.4,
            curve: FblaMotion.strongEaseOut,
          ),
        ),
      );
    });

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _emailUnconfirmed = false;
      _devVerifyCode = null;
    });

    debugPrint('[LOGIN] Attempting sign-in for ${_emailController.text.trim()}');

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      debugPrint('[LOGIN] Sign-in SUCCESS — session: ${res.session != null}');
      debugPrint('[LOGIN] User ID: ${res.session?.user.id}');
      debugPrint('[LOGIN] onboarding_complete: ${res.session?.user.userMetadata?['onboarding_complete']}');
      // Navigate directly — the Supabase auth broadcast stream may be dead
      // after a forced sign-out from an expired refresh token, so we cannot
      // rely on AuthGate's stream listener.  Pushing a fresh AuthGate as
      // the only route forces it to re-read currentSession (now valid).
      if (res.session != null && mounted) {
        debugPrint('[LOGIN] Navigating to fresh AuthGate');
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      debugPrint('[LOGIN] AuthException: ${e.message} (code: ${e.statusCode})');
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed')) {
        await _sendVerificationOtp();
      } else {
        setState(() { _errorMessage = _friendlyAuthError(e.message); });
      }
    } catch (e) {
      debugPrint('[LOGIN] Unexpected error: $e');
      setState(() { _errorMessage = 'Unable to reach the server. Please check your connection.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendVerificationOtp() async {
    final email = _emailController.text.trim();
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _emailUnconfirmed = true;
        _devVerifyCode = null;
        _errorMessage = null;
      });
    }
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Sign in failed. Please try again.';
  }

  void _showForgotPasswordSheet() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool sending = false;
    String? result;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return Padding(
              padding: EdgeInsets.only(
                left: FblaSpacing.xl,
                right: FblaSpacing.xl,
                top: FblaSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + FblaSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FblaColors.darkOutline,
                        borderRadius: BorderRadius.circular(FblaRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  Text(
                    'Reset Password',
                    style: FblaFonts.display(
                      fontSize: 22,
                      color: FblaColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.xs),
                  Text(
                    "Enter your email and we'll send a reset link.",
                    style: FblaFonts.body(
                      fontSize: 14,
                      color: FblaColors.darkTextSecond,
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FblaSpacing.md),
                      child: _StatusBanner(
                        message: result!,
                        isSuccess: result!.startsWith('✓'),
                      ),
                    ),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  ElevatedButton(
                    onPressed: sending
                        ? null
                        : () async {
                            setInner(() => sending = true);
                            try {
                              final email = emailCtrl.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setInner(() {
                                  result = 'Please enter a valid email address.';
                                  sending = false;
                                });
                                return;
                              }
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(email);
                              setInner(() {
                                result = '✓ Check your email for the reset link.';
                                sending = false;
                              });
                            } on AuthException catch (e) {
                              setInner(() {
                                result = e.message.isNotEmpty
                                    ? e.message
                                    : 'Something went wrong. Please try again.';
                                sending = false;
                              });
                            } catch (_) {
                              setInner(() {
                                result = 'Something went wrong. Please try again.';
                                sending = false;
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(FblaColors.onSecondary),
                            ),
                          )
                        : const Text('Send reset link'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop    = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: safeTop, bottom: safeBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FblaSpacing.xl,
                  FblaSpacing.lg,
                  FblaSpacing.xl,
                  FblaSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo mark
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo_64.png',
                        width: 44,
                        height: 44,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: FblaSpacing.lg),

                    // Staggered: Title
                    FadeTransition(
                      opacity: _staggeredOpacity[0],
                      child: SlideTransition(
                        position: _staggeredSlide[0],
                        child: Text(
                          'Welcome\nback.',
                          style: FblaFonts.display(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: FblaColors.darkTextPrimary,
                            letterSpacing: -1.5,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: FblaSpacing.sm),

                    // Blue accent rule
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: FblaColors.primaryLight,
                        borderRadius: BorderRadius.circular(FblaRadius.full),
                      ),
                    ),
                    const SizedBox(height: FblaSpacing.sm),

                    // Staggered: Subtitle
                    FadeTransition(
                      opacity: _staggeredOpacity[1],
                      child: SlideTransition(
                        position: _staggeredSlide[1],
                        child: Text(
                          'Sign in with your chapter email.',
                          style: FblaFonts.body(
                            fontSize: 15,
                            color: FblaColors.darkTextSecond,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form section ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: FblaSpacing.md),

                      // Staggered: Email field
                      FadeTransition(
                        opacity: _staggeredOpacity[2],
                        child: SlideTransition(
                          position: _staggeredSlide[2],
                          child: _AnimatedInputField(
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'you@school.edu',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.email_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              if (!v.contains('@')) {
                                return 'Please enter a valid email.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: FblaSpacing.lg),

                      // Staggered: Password field
                      FadeTransition(
                        opacity: _staggeredOpacity[3],
                        child: SlideTransition(
                          position: _staggeredSlide[3],
                          child: _AnimatedInputField(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: '••••••••',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.lock_outlined,
                            suffixIcon: Icons.visibility_outlined,
                            onSuffixTap: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password.';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleSignIn(),
                          ),
                        ),
                      ),

                      // Forgot password link — right-aligned, electric blue
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: FblaSpacing.sm),
                          child: TextButton(
                            onPressed: _showForgotPasswordSheet,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FblaSpacing.xs,
                                vertical: FblaSpacing.xs,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: FblaFonts.label(
                                fontSize: 12,
                                color: FblaColors.primaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: FblaSpacing.lg),

                      // Error banner
                      if (_errorMessage != null) ...[
                        _StatusBanner(message: _errorMessage!),
                        const SizedBox(height: FblaSpacing.lg),
                      ],

                      // Email unconfirmed — inline verification flow
                      if (_emailUnconfirmed) ...[
                        _EmailVerificationCard(
                          email: _emailController.text.trim(),
                          devCode: _devVerifyCode,
                          onVerified: () async {
                            setState(() {
                              _emailUnconfirmed = false;
                              _loading = true;
                              _errorMessage = null;
                            });
                            try {
                              await Supabase.instance.client.auth.signInWithPassword(
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                              );
                            } on AuthException catch (e) {
                              setState(() { _errorMessage = _friendlyAuthError(e.message); });
                            } catch (_) {
                              setState(() { _errorMessage = 'Sign in failed. Please try again.'; });
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                          onResend: _sendVerificationOtp,
                        ),
                        const SizedBox(height: FblaSpacing.lg),
                      ],

                      // Staggered: Sign-in button (gold gradient + glow)
                      FadeTransition(
                        opacity: _staggeredOpacity[4],
                        child: SlideTransition(
                          position: _staggeredSlide[4],
                          child: _SignInButton(
                            loading: _loading,
                            onPressed: _handleSignIn,
                          ),
                        ),
                      ),

                      const SizedBox(height: FblaSpacing.lg),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.sm),
                            child: Text(
                              'or',
                              style: FblaFonts.label(
                                fontSize: 12,
                                color: FblaColors.darkTextTertiary,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: FblaSpacing.lg),

                      // Create account button — outlined, subtle
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: FblaSpacing.md),
                          side: BorderSide(color: FblaColors.darkOutline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(FblaRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: Text(
                          'Create an account',
                          style: FblaFonts.label(
                            fontSize: 13,
                            color: FblaColors.darkTextSecond,
                          ),
                        ),
                      ),

                      const SizedBox(height: FblaSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Animated input field — minimal, clean, focuses to electric blue ──────────

class _AnimatedInputField extends StatefulWidget {
  const _AnimatedInputField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.suffixTooltip,
    this.obscureText = false,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? suffixTooltip;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Function(String)? onFieldSubmitted;

  @override
  State<_AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<_AnimatedInputField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _focusCtrl;
  late Animation<Color?> _borderColor;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _borderColor = ColorTween(
      begin: FblaColors.darkOutline,
      end: FblaColors.primaryLight,
    ).animate(CurvedAnimation(parent: _focusCtrl, curve: FblaMotion.strongEaseOut));

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _focusCtrl.forward();
      } else {
        _focusCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _focusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: FblaFonts.label(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: FblaSpacing.xs),
        AnimatedBuilder(
          animation: _borderColor,
          builder: (context, child) => TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: widget.obscureText,
            onFieldSubmitted: widget.onFieldSubmitted,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 18)
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? IconButton(
                      icon: Icon(widget.suffixIcon, size: 18),
                      tooltip: widget.suffixTooltip ??
                          (widget.obscureText
                              ? 'Show ${widget.label.toLowerCase()}'
                              : 'Hide ${widget.label.toLowerCase()}'),
                      onPressed: widget.onSuffixTap,
                    )
                  : null,
              filled: true,
              fillColor: FblaColors.darkSurfaceHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FblaSpacing.md,
                vertical: FblaSpacing.sm,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: FblaColors.darkOutline, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: _borderColor.value!, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: const BorderSide(
                  color: FblaColors.error,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: const BorderSide(
                  color: FblaColors.error,
                  width: 2,
                ),
              ),
            ),
            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}

// ─── Sign-in button — gold gradient with glow, scale-on-press ────────────────

class _SignInButton extends StatefulWidget {
  const _SignInButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: FblaMotion.press,
      reverseDuration: const Duration(milliseconds: 220),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.loading) return;
    HapticFeedback.mediumImpact();
    _pressCtrl.forward().then((_) => _pressCtrl.reverse());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: widget.loading ? null : FblaGradient.goldShimmer,
            color: widget.loading ? FblaColors.darkOutline : null,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            boxShadow: widget.loading ? null : FblaShadow.goldGlow,
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(FblaColors.onSecondary),
                    ),
                  )
                : Text(
                    'SIGN IN',
                    style: FblaFonts.label(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FblaColors.onSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Email verification card ──────────────────────────────────────────────────

class _EmailVerificationCard extends StatefulWidget {
  const _EmailVerificationCard({
    required this.email,
    required this.onVerified,
    required this.onResend,
    this.devCode,
  });

  final String email;
  final String? devCode;
  final Future<void> Function() onVerified;
  final Future<void> Function() onResend;

  @override
  State<_EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<_EmailVerificationCard> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() { _error = 'Enter the 6-digit code.'; });
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.email,
      );
      await widget.onVerified();
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() {
        _error = msg.contains('expired')
            ? 'Code expired. Tap Resend to get a new one.'
            : 'Incorrect code. Please try again.';
        _verifying = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Verification failed. Check your connection.';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FblaSpacing.md),
      decoration: BoxDecoration(
        color: FblaColors.secondary.withAlpha(12),
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(color: FblaColors.secondary.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  color: FblaColors.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verify your email to continue',
                  style: FblaFonts.label(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We sent a 6-digit code to ${widget.email}',
            style: FblaFonts.body(
              fontSize: 12,
              color: FblaColors.darkTextSecond,
            ),
          ),
          if (widget.devCode != null) ...[
            const SizedBox(height: 4),
            Text(
              'DEV: ${widget.devCode}',
              style: FblaFonts.monoLabel(
                fontSize: 11,
                color: FblaColors.secondary,
                letterSpacing: 2.0,
              ),
            ),
          ],
          const SizedBox(height: FblaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: FblaFonts.monoStat(
                    fontSize: 22,
                    color: FblaColors.darkTextPrimary,
                  ).copyWith(letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: FblaColors.darkTextTertiary,
                      letterSpacing: 2,
                      fontSize: 18,
                    ),
                    filled: true,
                    fillColor: FblaColors.darkSurfaceHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: FblaSpacing.md,
                      vertical: FblaSpacing.sm,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                      borderSide: BorderSide(color: FblaColors.darkOutline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                      borderSide: const BorderSide(color: FblaColors.primary, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              const SizedBox(width: FblaSpacing.sm),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FblaColors.secondary,
                    foregroundColor: FblaColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(FblaColors.onSecondary),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: FblaFonts.label(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: FblaColors.onSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: FblaFonts.body(fontSize: 12, color: FblaColors.error),
            ),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: _resending
                ? null
                : () async {
                    setState(() { _resending = true; _error = null; });
                    await widget.onResend();
                    if (mounted) setState(() { _resending = false; _otpCtrl.clear(); });
                  },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: FblaColors.primary,
            ),
            child: Text(
              _resending ? 'Sending…' : 'Resend code',
              style: FblaFonts.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FblaColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status banner (error or success) — shake on error ──────────────────────

class _StatusBanner extends StatefulWidget {
  const _StatusBanner({required this.message, this.isSuccess = false});

  final String message;
  final bool isSuccess;

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<Offset> _shakeOffset;

  @override
  void initState() {
    super.initState();
    if (!widget.isSuccess) {
      _shakeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _shakeOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
      );
      // Perform shake animation
      _shakeCtrl.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeCtrl.reverse();
        }
      });
      _shakeCtrl.forward();
    } else {
      _shakeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1),
      );
      _shakeOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
        _shakeCtrl,
      );
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSuccess ? FblaColors.success : FblaColors.error;

    return SlideTransition(
      position: _shakeOffset,
      child: Semantics(
        liveRegion: true,
        label: widget.isSuccess ? 'Success: ${widget.message}' : 'Error: ${widget.message}',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md,
            vertical: FblaSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: color.withAlpha(55)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  widget.isSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline_rounded,
                  color: color,
                  size: 15,
                ),
              ),
              const SizedBox(width: FblaSpacing.sm),
              Expanded(
                child: Text(
                  widget.message,
                  style: FblaFonts.body(
                    fontSize: 12,
                    color: color,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
