import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/user.dart';
import 'package:akletna_frontend/models/user_profile.dart';
import 'package:akletna_frontend/services/profile_service.dart';
import 'package:akletna_frontend/screens/home/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryProfiles extends ProfileService {
  UserProfile profile = UserProfile(
    user: User(id: 4, name: 'Owner', email: 'owner@example.test'),
  );
  int saves = 0;
  bool fail = false;
  @override
  Future<UserProfile> get() async => profile;
  @override
  Future<UserProfile> update(String name) async {
    saves++;
    if (fail) throw StateError('offline');
    return profile = UserProfile(
      user: User(id: 4, name: name, email: profile.user.email),
    );
  }
}

void main() {
  Future<void> open(WidgetTester tester, MemoryProfiles service) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ProfileScreen(
          user: service.profile.user,
          profileService: service,
          onPreferences: () {},
          onSaved: () {},
          onRecipes: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saved name persists when editor reopens', (tester) async {
    final service = MemoryProfiles();
    await open(tester, service);
    expect(find.text('owner@example.test'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New name');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(service.saves, 1);
    expect(service.profile.user.name, 'New name');
    await tester.pumpWidget(const SizedBox());
    await open(tester, service);
    expect(find.text('New name'), findsOneWidget);
  });
  testWidgets('network errors preserve the profile and allow retry', (
    tester,
  ) async {
    final service = MemoryProfiles();
    await open(tester, service);
    expect(find.text('O'), findsOneWidget);
    service.fail = true;
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load or update your profile. Please retry.'),
      findsOneWidget,
    );
    expect(service.profile.user.name, 'Owner');
  });
}
