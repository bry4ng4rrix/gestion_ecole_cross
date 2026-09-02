import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifiantCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identifiantCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_identifiantCtrl.text.trim(), _passwordCtrl.text);
      // La redirection est gérée par le `redirect` du router en réaction au changement d'état auth.
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Identifiants incorrects ou compte inactif';
      if (data is Map) {
        message = (data['detail'] ?? (data['non_field_errors'] is List ? data['non_field_errors'][0] : null)) ?? message;
      }
      setState(() => _error = message);
    } catch (_) {
      setState(() => _error = 'Impossible de contacter le serveur.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF312E81), Color(0xFF0F172A), Color(0xFF581C87)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    
                    const SizedBox(height: 28),
                    Card(
                      color: const Color(0xE60B0F1A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: Text('Connexion', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 4),
                              const Center(
                                child: Text(
                                  'Saisissez vos identifiants pour accéder à votre espace',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              _darkField(
                                controller: _identifiantCtrl,
                                label: 'Email ou matricule',
                                icon: Icons.mail_outline,
                                hint: 'exemple@lycee.mg ou matricule',
                              ),
                              const SizedBox(height: 14),
                              _darkField(
                                controller: _passwordCtrl,
                                label: 'Mot de passe',
                                icon: Icons.lock_outline,
                                obscure: _obscure,
                                suffix: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 14)),
                                  child: _loading
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w600 , color: Colors.white)),
                                ),
                              ),
                              Center(
                                child: TextButton(
                                  onPressed: () => context.go('/register'),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                      children: [
                                        TextSpan(text: "Pas encore de compte ? "),
                                        TextSpan(text: 'Créer un compte', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  '© ${DateTime.now().year} Bryan Garrix • Tous droits réservés',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ce champ est requis' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
          ),
        ),
      ],
    );
  }
}

