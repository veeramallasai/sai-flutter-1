import 'package:flutter/material.dart';

import '../core/auth/local_auth_session.dart';
import '../core/network/api_client.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _validateSession();
  }

  Future<bool> _validateSession() async {
    if (!await LocalAuthSession.hasToken) return false;
    try {
      await ApiClient().get('/api/v1/auth/me');
      return true;
    } catch (error) {
      debugPrint('Session validation failed: $error');
      await LocalAuthSession.clear();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
