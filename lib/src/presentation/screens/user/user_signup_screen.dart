import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class UserSignUpScreen extends StatefulWidget {
    final VoidCallback onTap;
    const UserSignUpScreen({Key? key, required this.onTap}) : super(key: key);

    @override
    State<UserSignUpScreen> createState() => _UserSignUpScreenState();
}

class _UserSignUpScreenState extends State<UserSignUpScreen> {
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    final _authRepository = FirebaseAuthRepository();
    bool _isLoading = false;

    Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Passwords don't match!"), backgroundColor: Colors.red),
    );
    return;
    }

    setState(() => _isLoading = true);
    try {
    await _authRepository.signUpWithEmailAndPassword(
    email: _emailController.text.trim(),
    password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(); // Go back on success
    } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
    );
    } finally {
    if (mounted) setState(() => _isLoading = false);
    }
    }

    @override
    Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(title: const Text('Register')),
    body: Center(
    child: SingleChildScrollView(
    padding: const EdgeInsets.all(24.0),
    child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 400),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    const Text('Create an Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
    const SizedBox(height: 16),
    CustomTextField(
    controller: _confirmPasswordController,
      hintText: 'Confirm Password',
        prefixIcon: Icons.lock_outline,
          obscureText: true,
          ),
            const SizedBox(height: 24),
              CustomButton(onPressed: _isLoading ? () {} : _signUp, text: 'Sign Up', isLoading: _isLoading),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already a member?"),
                    TextButton(onPressed: widget.onTap, child: const Text('Login now')),
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