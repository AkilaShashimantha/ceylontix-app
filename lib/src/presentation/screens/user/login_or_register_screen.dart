    import 'package:flutter/material.dart';
    import 'user_login_screen.dart';
    import 'user_signup_screen.dart';

    class LoginOrRegisterScreen extends StatefulWidget {
      const LoginOrRegisterScreen({Key? key}) : super(key: key);

      @override
      State<LoginOrRegisterScreen> createState() => _LoginOrRegisterScreenState();
    }

    class _LoginOrRegisterScreenState extends State<LoginOrRegisterScreen> {
      // Initially, show the login screen
      bool showLoginPage = true;

      // Toggle between login and register screens
      void toggleScreens() {
        setState(() {
          showLoginPage = !showLoginPage;
        });
      }

      @override
      Widget build(BuildContext context) {
        if (showLoginPage) {
          return UserLoginScreen(onTap: toggleScreens);
        } else {
          return UserSignUpScreen(onTap: toggleScreens);
        }
      }
    }
    
