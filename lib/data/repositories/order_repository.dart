import '../../core/network/api_client.dart';
import '../models/order_model.dart';
import '../remote/order_remote_source.dart';

/// Order ownership is enforced by the authenticated backend. The mobile/web
/// client never needs a Firebase UID to read or mutate customer orders.
class OrderRepository {
  OrderRepository({OrderRemoteSource? remoteSource, ApiClient? client})
      : _remoteSource = remoteSource ?? OrderRemoteSource(),
        _client = client ?? ApiClient();

  final OrderRemoteSource _remoteSource;
  final ApiClient _client;

  bool get isSignedIn => true;

  Stream<List<OrderModel>> watchCurrentUserOrders({int limit = 50}) =>
      _remoteSource.watchUserOrders('', limit: limit);

  Stream<List<OrderModel>> watchOrdersByStatus(String status, {int limit = 50}) {
    final String normalized = status.trim().toLowerCase();
    return watchCurrentUserOrders(limit: limit).map((orders) {
      if (normalized.isEmpty || normalized == 'all') return orders;
      return List<OrderModel>.unmodifiable(
        orders.where((OrderModel order) => order.status == normalized),
      );
    });
  }

  Future<List<OrderModel>> getCurrentUserOrders({int limit = 50}) =>
      _remoteSource.getUserOrders('', limit: limit);

  Stream<OrderModel?> watchOrder(String orderId) =>
      _remoteSource.watchOrder(orderId);

  Future<OrderModel?> getOrder(String orderId) => _remoteSource.getOrder(orderId);

  Future<String> createOrder(OrderModel order) =>
      _remoteSource.createOrder(order);

  Future<void> updateOrder(OrderModel order) =>
      _remoteSource.updateOrder(order);

  Future<void> cancelOrder({required String orderId, String reason = ''}) =>
      _remoteSource.cancelOrder(orderId: orderId, reason: reason);

  Future<int> reorder(String orderId) async {
    final response = await _client.post('/api/v1/orders/${orderId.trim()}/reorder');
    final dynamic value = response.data;
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Future<void> updateOrderStatus({required String orderId, required String status, String note = ''}) =>
      _remoteSource.updateOrderStatus(orderId: orderId, status: status, note: note);

  Future<void> updatePaymentStatus({required String orderId, required String paymentStatus, String paymentId = '', String transactionId = ''}) =>
      _remoteSource.updatePaymentStatus(orderId: orderId, paymentStatus: paymentStatus, paymentId: paymentId, transactionId: transactionId);

  Future<List<OrderModel>> getActiveOrders({int limit = 50}) async {
    final orders = await getCurrentUserOrders(limit: limit);
    return List<OrderModel>.unmodifiable(orders.where((o) => !o.isDelivered && !o.isCancelled && !o.isFailed));
  }

  Future<List<OrderModel>> getCompletedOrders({int limit = 50}) async {
    final orders = await getCurrentUserOrders(limit: limit);
    return List<OrderModel>.unmodifiable(orders.where((o) => o.isDelivered || o.isCancelled || o.isFailed));
  }
}
