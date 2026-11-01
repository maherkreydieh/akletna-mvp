class AuthResponse {
  final String token;
  final String email;

  AuthResponse({required this.token, required this.email});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}
