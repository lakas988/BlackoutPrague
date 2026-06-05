import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_storage_service.dart';
import '../widgets/profile_form.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = ProfileStorageService();
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _storage.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: FutureBuilder<UserProfile?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data ?? UserProfile.empty();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_outline, size: 34, color: Color(0xFFFFD166)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName.isEmpty ? 'Místní profil' : profile.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text('${profile.role.czechLabel} · ${profile.district}'),
                              const SizedBox(height: 8),
                              const Text('Citlivé údaje zůstávají pouze v tomto zařízení.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ProfileForm(
                  initialProfile: profile,
                  submitLabel: 'Uložit profil',
                  onSubmit: _saveProfile,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await _storage.saveProfile(profile);

    if (!mounted) {
      return;
    }

    setState(() {
      _profileFuture = Future.value(profile);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil byl uložen v zařízení.')),
    );
  }
}