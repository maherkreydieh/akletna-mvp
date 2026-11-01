import 'user.dart';

class UserProfile {
  const UserProfile({required this.user});
  final User user;
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      UserProfile(user: User.fromJson(json));
}
