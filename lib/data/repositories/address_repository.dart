import '../models/address_model.dart';
import '../remote/address_remote_source.dart';

/// Address data is owned by the Spring Boot API. Authentication is resolved
/// from the JWT attached by ApiClient, so Firebase is never required here.
class AddressRepository {
  AddressRepository({AddressRemoteSource? remoteSource})
      : _remoteSource = remoteSource ?? AddressRemoteSource();

  final AddressRemoteSource _remoteSource;

  Stream<List<AddressModel>> watchAddresses() async* {
    yield await getAddresses();
  }

  Future<List<AddressModel>> getAddresses() => _remoteSource.getAddresses();

  Future<AddressModel> saveAddress(AddressModel address) =>
      _remoteSource.saveAddress(address);

  Future<void> deleteAddress(String addressId) {
    if (addressId.trim().isEmpty) return Future<void>.value();
    return _remoteSource.deleteAddress(addressId);
  }

  Future<AddressModel> setDefault(String addressId) {
    if (addressId.trim().isEmpty) {
      throw ArgumentError.value(addressId, 'addressId', 'Address ID is required.');
    }
    return _remoteSource.setDefault(addressId);
  }
}
