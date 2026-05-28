import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _pollCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _pollCount = 0;
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _startPolling();
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://music.youtube.com'));
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkCookies());
  }

  Future<void> _checkCookies() async {
    if (!mounted || _pollCount > 30) {
      _pollTimer?.cancel();
      return;
    }
    _pollCount++;

    final result = await _controller.runJavaScriptReturningResult('document.cookie');
    String cookieString = result as String;
    if (cookieString.startsWith('"') && cookieString.endsWith('"')) {
      cookieString = cookieString.substring(1, cookieString.length - 1);
    }

    if (cookieString.contains('SAPISID') || cookieString.contains('__Secure-3PAPISID')) {
      _pollTimer?.cancel();
      if (mounted) _completeLogin(cookieString);
    }
  }

  void _completeLogin(String cookies) {
    ref.read(settingsProvider.notifier).setCookies(cookies);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully signed in to YouTube Music')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
