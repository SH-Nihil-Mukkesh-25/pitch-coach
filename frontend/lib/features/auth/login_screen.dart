import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  final bool isSignUpInitial;
  const LoginScreen({super.key, this.isSignUpInitial = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isSignUp;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUpInitial;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Firebase Email Auth ────────────────────────────────────────────────────

  Future<void> _handleAuthSubmitted() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isLoading) return; // prevent double-submit

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    bool success;

    if (_isSignUp) {
      final String name = _nameController.text.trim();
      success = await userProvider.firebaseSignUp(
        name: name,
        email: email,
        password: password,
      );
    } else {
      success = await userProvider.firebaseLogin(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSignUp ? 'Account created successfully!' : 'Welcome back!',
          ),
          backgroundColor: AppColors.primaryPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (_isSignUp) {
        context.go('/profile-setup');
      } else {
        context.go('/home');
      }
    } else {
      // Show error from provider
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userProvider.error ?? 'Authentication failed. Please try again.',
          ),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      userProvider.clearError();
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isLoading) return;

    final success = await userProvider.firebaseSignInWithGoogle();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Signed in with Google!'),
          backgroundColor: AppColors.primaryPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.go('/home');
    } else if (userProvider.error != null) {
      // Only show error if it's a real failure (not a user cancellation)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.error!),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      userProvider.clearError();
    }
    // If success==false and error==null the user simply cancelled — do nothing.
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: AppAtmosphere(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Top Bar: Back Button & Theme Toggle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const ThemeToggleButton(size: 40, compact: true),
                  ],
                ),

                const SizedBox(height: 24),

                // App Title / Branding Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withValues(
                                alpha: isDark ? 0.4 : 0.25,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Pitch ',
                              style: AppTextStyles.headingXL.copyWith(
                                color: AppColors.textPrimaryOf(context),
                                fontSize: 28,
                              ),
                            ),
                            TextSpan(
                              text: 'Coach',
                              style: AppTextStyles.headingXL.copyWith(
                                color: isDark
                                    ? AppColors.primaryPurpleLight
                                    : AppColors.primaryPurple,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Login / Sign Up Tab Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.borderOf(context),
                      width: 0.8,
                    ),
                    boxShadow: AppColors.softShadowOf(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isSignUp
                                  ? (isDark ? const Color(0xFF38383A) : AppColors.primaryPurple)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: (!_isSignUp && isDark)
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Login',
                              style: AppTextStyles.button.copyWith(
                                color: !_isSignUp
                                    ? Colors.white
                                    : (isDark
                                        ? const Color(0xFF8E8E93)
                                        : AppColors.textSecondaryOf(context)),
                                fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isSignUp
                                  ? (isDark ? const Color(0xFF38383A) : AppColors.primaryPurple)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: (_isSignUp && isDark)
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign Up',
                              style: AppTextStyles.button.copyWith(
                                color: _isSignUp
                                    ? Colors.white
                                    : (isDark
                                        ? const Color(0xFF8E8E93)
                                        : AppColors.textSecondaryOf(context)),
                                fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Form Fields
                if (_isSignUp) ...[
                  Text(
                    'Full Name',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInputField(
                    controller: _nameController,
                    hint: 'e.g. Vijay',
                    icon: Icons.person_outline_rounded,
                    validator: (val) {
                      if (_isSignUp && (val == null || val.trim().isEmpty)) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                Text(
                  'Email Address',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInputField(
                  controller: _emailController,
                  hint: 'vanakamnanba@gmail.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!val.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                Text(
                  'Password',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInputField(
                  controller: _passwordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondaryOf(context),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                if (!_isSignUp) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.primaryPurpleLight
                              : AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Submit Button (Email / Password)
                Consumer<UserProvider>(
                  builder: (context, provider, _) => GradientButton(
                    text: provider.isLoading
                        ? 'Please wait...'
                        : (_isSignUp ? 'Create Account' : 'Sign In'),
                    variant: GradientButtonVariant.primary,
                    height: 52,
                    isLoading: provider.isLoading,
                    onPressed: provider.isLoading ? null : _handleAuthSubmitted,
                  ),
                ),

                const SizedBox(height: 20),

                // OR divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.dividerOf(context)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.dividerOf(context)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Google Sign-In Button
                Consumer<UserProvider>(
                  builder: (context, provider, _) => _GoogleSignInButton(
                    onPressed: provider.isLoading ? null : _handleGoogleSignIn,
                    isLoading: provider.isLoading,
                  ),
                ),

                const SizedBox(height: 12),

                // Continue as Guest Option
                GradientButton(
                  text: 'Continue as Guest',
                  variant: GradientButtonVariant.secondary,
                  height: 52,
                  icon: Icons.person_outline_rounded,
                  backgroundColor: AppColors.cardOf(context),
                  borderColor: AppColors.borderOf(context),
                  textColor: AppColors.textPrimaryOf(context),
                  onPressed: () async {
                    await Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).loginAsGuest();
                    if (!context.mounted) return;
                    context.go('/home');
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = AppColors.isDark(context);
    final border = AppColors.borderOf(context);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark
              ? AppColors.primaryPurpleLight
              : AppColors.primaryPurple,
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cardOf(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryPurple,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.dangerRed),
        ),
      ),
    );
  }
}

// ── Google Sign-In Button ────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GoogleSignInButton({required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cardOf(context),
          side: BorderSide(color: AppColors.borderOf(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryPurple,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Draws the Google "G" multicolour logo using a CustomPainter.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset c = Offset(r, r);

    // Draw outer circle filled white to simulate a "chip"
    canvas.drawCircle(c, r, Paint()..color = Colors.white);

    const double padding = 0.15;
    final double ir = r * (1 - padding * 2); // inner radius

    final Paint paint = Paint()..style = PaintingStyle.stroke;

    // Blue arc  (top-right, 290°→70°)
    paint
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = ir * 0.36;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ir * 0.72),
      _deg(-70),
      _deg(140),
      false,
      paint,
    );

    // Red arc  (top-left, 220°→290°)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ir * 0.72),
      _deg(-140),
      _deg(-70),
      false,
      paint,
    );

    // Yellow arc  (bottom-left, 140°→220°)
    paint.color = const Color(0xFFFBBC04);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ir * 0.72),
      _deg(140),
      _deg(80),
      false,
      paint,
    );

    // Green arc  (bottom-right, 70°→140°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ir * 0.72),
      _deg(70),
      _deg(70),
      false,
      paint,
    );

    // Horizontal bar (right side of the G cutout)
    final double barY = c.dy;
    final double barLeft = c.dx + ir * 0.0;
    final double barRight = c.dx + ir * 0.72 + ir * 0.36 / 2;
    paint
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = ir * 0.36;
    canvas.drawLine(Offset(barLeft, barY), Offset(barRight, barY), paint);
  }

  double _deg(double degrees) => degrees * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
