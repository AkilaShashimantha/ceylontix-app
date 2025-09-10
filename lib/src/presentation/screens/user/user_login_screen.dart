import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

    class UserLoginScreen extends StatefulWidget {
      final VoidCallback onTap;
      const UserLoginScreen({Key? key, required this.onTap}) : super(key: key);

      @override
      State<UserLoginScreen> createState() => _UserLoginScreenState();
    }

    class _UserLoginScreenState extends State<UserLoginScreen> {
      @override
      void initState() {
        super.initState();
      }

    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _authRepository = FirebaseAuthRepository();
    bool _isLoading = false;

      Future<void> _signIn() async {
        setState(() => _isLoading = true);
        try {
          await _authRepository.signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
           if (mounted) Navigator.of(context).pop(); // Go back on success
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
       Future<void> _signInWithGoogle() async {
        setState(() => _isLoading = true);
        try {
          await _authRepository.signInWithGoogle();
           if (mounted) Navigator.of(context).pop(); // Go back on success
        } catch (e) {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                 constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Welcome Back!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(onPressed: _signIn, text: 'Login', isLoading: _isLoading),
                    const SizedBox(height: 16),
                    const Text("OR"),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _GoogleGIcon(),
                          SizedBox(width: 12),
                          Text('Sign in with Google'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Not a member?"),
                        TextButton(onPressed: widget.onTap, child: const Text('Register now')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    class _GoogleGIcon extends StatelessWidget {
      const _GoogleGIcon({super.key});

      @override
      Widget build(BuildContext context) {
        return Image.asset(
          'assets/logo/Google_Icon.png',
          width: 20,
          height: 20,
          errorBuilder: (context, error, stack) => const Icon(Icons.g_mobiledata, size: 20),
        );
      }
    }
    
