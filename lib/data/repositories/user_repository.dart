import 'dart:async';

import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Customer profile repository backed only by Spring Boot/PostgreSQL.
class UserRepository {
  UserRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Stream<UserModel?> watchCurrentUser() async* {
    yield await getCurrentUser();
  }

  Future<UserModel> getCurrentUser() async {
    final dynamic raw = (await _apiClient.get('/api/v1/users/me')).data;
    if (raw is! Map) throw StateError('Invalid profile response from server.');
    return UserModel.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> saveProfile(UserModel profile) async {
    await _apiClient.put('/api/v1/users/me', body: <String, dynamic>{
      'firstName': profile.firstName.trim(),
      'lastName': profile.lastName.trim(),
      'phoneNumber': profile.phoneNumber.trim(),
      'photoUrl': profile.photoUrl.trim(),
      'shoppingMode': profile.shoppingMode == 'shop' ? 'shop' : 'home',
      'accountType': profile.isShopOwner ? 'shop_owner' : 'customer',
    });
  }

  Future<void> updateShoppingMode(String mode) async {
    final UserModel profile = await getCurrentUser();
    await saveProfile(profile.copyWith(
      shoppingMode: mode.trim().toLowerCase() == 'shop' ? 'shop' : 'home',
    ));
  }

  Future<void> syncCurrentUser({String? accountType}) async {
    final UserModel profile = await getCurrentUser();
    await _apiClient.put('/api/v1/users/me', body: <String, dynamic>{
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'phoneNumber': profile.phoneNumber,
      'photoUrl': profile.photoUrl,
      'shoppingMode': profile.shoppingMode,
      'accountType': accountType == 'shop_owner' ? 'shop_owner' : (profile.isShopOwner ? 'shop_owner' : 'customer'),
    });
  }
}
