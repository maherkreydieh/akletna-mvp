import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onPreferences,
    required this.onSaved,
    required this.onRecipes,
    required this.onLogout,
    this.profileService,
  });
  final User user;
  final VoidCallback onPreferences, onSaved, onRecipes, onLogout;
  final ProfileService? profileService;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.user.name);
  late UserProfile _profile = UserProfile(user: widget.user);
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.profileService != null) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      _perform(() => widget.profileService!.get(), loaded: true);
  Future<void> _perform(
    Future<UserProfile> Function() action, {
    bool loaded = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await action();
      if (mounted) {
        setState(() {
          _profile = profile;
          if (loaded) {
            _name.text = profile.user.name;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load or update your profile. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _profile.user.name.trim().isEmpty
        ? 'A'
        : _profile.user.name.trim().characters.first.toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(radius: 40, child: Text(initials)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      enabled: !_busy && widget.profileService != null,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Account email',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    SelectableText(
                      widget.user.email.isEmpty
                          ? 'Email unavailable'
                          : widget.user.email,
                    ),
                    if (widget.profileService != null) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _perform(
                                () => widget.profileService!.update(_name.text),
                              ),
                        child: const Text('Save profile'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Food Preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onPreferences,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('Saved Recipes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onSaved,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('My Recipes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onRecipes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
