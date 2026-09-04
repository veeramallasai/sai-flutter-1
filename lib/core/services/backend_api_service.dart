import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../network/api_response.dart';

class BackendApiService {
  BackendApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ApiResponse<dynamic>> healthCheck() =>
      _client.get(ApiEndpoints.health);

  Future<ApiResponse<dynamic>> getProducts({
    String category = '',
    String shoppingMode = 'home',
    int limit = 200,
  }) {
    return _client.get(
      ApiEndpoints.products,
      queryParameters: <String, dynamic>{
        if (category.trim().isNotEmpty)
          'category': category.trim().toLowerCase(),
        'shoppingMode': shoppingMode == 'shop' ? 'shop' : 'home',
        'limit': limit,
      },
    );
  }

  Future<ApiResponse<dynamic>> createOrder(Map<String, dynamic> order) =>
      _client.post(ApiEndpoints.orders, body: order);

  Future<ApiResponse<dynamic>> updateOrder(
    String orderId,
    Map<String, dynamic> changes,
  ) => _client.patch(ApiEndpoints.order(orderId), body: changes);

  Future<ApiResponse<dynamic>> createPayment(Map<String, dynamic> payment) =>
      _client.post(ApiEndpoints.payments, body: payment);

  Future<ApiResponse<dynamic>> validateCoupon({
    required String code,
    required double subtotal,
  }) => _client.post(
    '${ApiEndpoints.checkout}/coupon',
    body: <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'subtotal': subtotal,
    },
  );

  Future<ApiResponse<dynamic>> sendPasswordSetupOtp(String email) =>
      _client.post(
        ApiEndpoints.passwordSetupSend(),
        body: <String, dynamic>{'email': email},
      );

  Future<ApiResponse<dynamic>> verifyPasswordSetupOtp({
    required String email,
    required String otp,
  }) => _client.post(
    ApiEndpoints.passwordSetupVerify(),
    body: <String, dynamic>{
      'email': email,
      'otp': otp,
    },
  );

  Future<ApiResponse<dynamic>> confirmPasswordSetup({
    required String email,
    required String otp,
    required String password,
  }) => _client.post(
    ApiEndpoints.passwordSetupConfirm(),
    body: <String, dynamic>{
      'email': email,
      'otp': otp,
      'password': password,
    },
  );

  Future<ApiResponse<dynamic>> resendPasswordSetupOtp(String email) =>
      _client.post(
        ApiEndpoints.passwordSetupResend(),
        body: <String, dynamic>{'email': email},
      );

  void dispose() => _client.dispose();
}
