// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _inactivity = TextEditingController();

  Future<void> _save(String gymId) async {
    await AppSupabase.client.from('gym_settings')
      .update({'inactivity_threshold_days': int.tryParse(_inactivity.text) ?? 7})
      .eq('gym_id', gymId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Settings')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Membership thresholds'),
        const SizedBox(height: 12),
        AppTextField(controller: _inactivity, label: 'No-show threshold (days)', keyboard: TextInputType.number),
        const SizedBox(height: 24),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _save(profile.gymId), label: const Text('Save'), icon: const Icon(Icons.save)),
    );
  }
}

