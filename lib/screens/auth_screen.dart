import 'package:flutter/material.dart';

import '../security/auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _registerMode = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registerMode = !widget.auth.hasAccounts;
    if (widget.auth.lastUser != null) _userCtrl.text = widget.auth.lastUser!;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = _registerMode
        ? await widget.auth.register(_userCtrl.text, _passCtrl.text)
        : await widget.auth.login(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
    // On success the AuthController notifies and the gate swaps this screen out.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              scheme.tertiary,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, size: 64, color: scheme.onPrimary),
                  const SizedBox(height: 12),
                  Text('StudyFlow',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.bold)),
                  Text('Your offline study companion',
                      style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85))),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _registerMode
                                  ? 'Create your account'
                                  : 'Welcome back',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _registerMode
                                  ? 'Set a username and password. Your data stays on this device.'
                                  : 'Sign in to open your study data.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _userCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              onFieldSubmitted: (_) =>
                                  _registerMode ? null : _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            if (_registerMode) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: _obscure,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (v) => v != _passCtrl.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 18, color: scheme.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: TextStyle(color: scheme.error)),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(_registerMode
                                        ? 'Create account'
                                        : 'Sign in'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _registerMode = !_registerMode;
                                        _error = null;
                                      }),
                              child: Text(_registerMode
                                  ? 'I already have an account'
                                  : 'Create a new account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Passwords are stored only as salted PBKDF2 hashes on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                        fontSize: 12),
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
