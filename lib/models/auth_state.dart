import 'package:flutter/foundation.dart';

@immutable
abstract class AuthState {}

class AuthSuccess extends AuthState {
  final String accessToken;
  AuthSuccess(this.accessToken);
}

class AuthFailure extends AuthState {
  final String error;
  final String? message;
  AuthFailure(this.error, this.message);
}

class AuthCancelled extends AuthState {}
