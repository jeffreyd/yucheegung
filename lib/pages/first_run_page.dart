import 'package:flutter/material.dart';
import '../models/jellyfin_server.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';
import 'library_selection_page.dart';

class FirstRunPage extends StatefulWidget {
  const FirstRunPage({super.key});

  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _settingsService = SettingsService();
  final _jellyfinService = JellyfinService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final baseUrl = JellyfinServer.parseBaseUrl(_urlController.text);

      final server = JellyfinServer(
        baseUrl: baseUrl,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      // Authenticate with Jellyfin server
      final auth = await _jellyfinService.authenticate(server);

      // Save server configuration and mark first run complete
      await _settingsService.saveServer(server);
      await _settingsService.setFirstRunComplete();

      if (mounted) {
        // Navigate to library selection page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LibrarySelectionPage(
              server: server,
              auth: auth,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App title
                  const Text(
                    'YuCheeGung',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jellyfin Audio Player',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Instructions
                  Text(
                    'Connect to your Jellyfin server',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Server URL field
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://my.jellyfinserver.com:8096',
                      helperText: 'Defaults to http:// and port 8096',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a server URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Connect button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
