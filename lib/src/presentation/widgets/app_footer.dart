import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo/app_logo.png', height: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'CeylonTix',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (isWide)
                const Text(
                  '© 2025 CeylonTix. All rights reserved.',
                  style: TextStyle(color: Colors.white70),
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Privacy', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Terms', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Contact', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
