import '../models/cart_item_model.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';
import '../remote/cart_remote_source.dart';

class CartRepository {
  CartRepository({
    CartRemoteSource? remoteSource,
  }) : _remoteSource = remoteSource ?? CartRemoteSource();

  final CartRemoteSource _remoteSource;

  // Cart endpoints are authenticated by the JWT attached by ApiClient.
  // The backend resolves the current user from that token, so Firebase UID is
  // neither needed nor safe to access in the local-JWT customer app.
  String get currentUserId => 'session-user';

  Stream<CartModel> watchCart() {
    return _remoteSource.watchCart(_requireUserId());
  }

  Future<CartModel> getCart() {
    return _remoteSource.getCart(_requireUserId());
  }

  Future<void> addProduct(
      ProductModel product, {
        int quantity = 1,
        String? unit,
        String? shoppingMode,
      }) {
    final CartItemModel item = CartItemModel.fromProduct(
      product,
      quantity: quantity,
      unit: unit,
      shoppingMode: shoppingMode,
    );
    return _remoteSource.addItem(_requireUserId(), item);
  }

  Future<void> updateQuantity(String itemId, int quantity) {
    return _remoteSource.updateQuantity(
      userId: _requireUserId(),
      itemId: itemId,
      quantity: quantity,
    );
  }

  Future<void> removeItem(String itemId) {
    return _remoteSource.removeItem(_requireUserId(), itemId);
  }

  Future<void> applyCoupon(String couponCode, double discount) {
    return _remoteSource.applyCoupon(
      userId: _requireUserId(),
      couponCode: couponCode,
      discount: discount,
    );
  }

  Future<void> removeCoupon() {
    return _remoteSource.removeCoupon(_requireUserId());
  }

  Future<void> clearCart() {
    return _remoteSource.clearCart(_requireUserId());
  }

  String _requireUserId() => currentUserId;
}
