// lib/utils/auth_provider.dart

import 'package:flutter/material.dart';
import '../models/auth_models.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final user = kAppUsers.where(
      (u) => u.username.toLowerCase() == username.toLowerCase().trim() &&
             u.password == password,
    ).firstOrNull;

    _isLoading = false;

    if (user != null) {
      _currentUser = user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid username or password';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
