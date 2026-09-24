import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(sessionProvider).signIn(_username.text.trim(), _password.text);
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.confirmation_number_outlined, size: 54, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 22),
          Text('BiletFlow', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Event check-in', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 36),
          TextFormField(
            controller: _username,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Login', prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter your login' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: true,
            onFieldSubmitted: (_) => _submit(),
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
          ),
          const SizedBox(height: 16),
          Text('Use your BiletFlow account assigned to an event.', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        ]),
      )),
    ))),
  );
}
