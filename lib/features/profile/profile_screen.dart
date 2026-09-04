import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/auth/local_auth_session.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'widgets/logout_button.dart';
import 'widgets/order_summary_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_item.dart';
import 'widgets/profile_shopping_mode_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _users = UserRepository();
  final OrderRepository _orders = OrderRepository();
  bool _savingMode = false;
  bool _loggingOut = false;
  late Future<UserModel> _profileFuture;
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _profileFuture = _users.getCurrentUser();
    _ordersFuture = _orders.getCurrentUserOrders(limit: 50);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await LocalAuthSession.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _changeShoppingMode(String mode) async {
    if (_savingMode) return;
    setState(() => _savingMode = true);
    try {
      await _users.updateShoppingMode(mode);
      if (!mounted) return;
      setState(_reload);
      _message(mode == 'shop' ? 'Shop Owner mode selected.' : 'Home Shopping mode selected.');
    } catch (_) {
      if (mounted) _message('Unable to change shopping mode.', error: true);
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  Widget _orderOverview() => FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          final orders = snapshot.data ?? <OrderModel>[];
          final int active = orders.where((o) => !o.isDelivered && !o.isCancelled && !o.isFailed).length;
          final double savings = orders.fold<double>(0, (value, order) => value + order.totalSavings);
          return OrderSummaryCard(
            totalOrders: orders.length,
            activeOrders: active,
            totalSavings: savings,
            onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
          );
        },
      );

  void _setLoginPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.error : const Color(0xFF1B5E20),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      body: SafeArea(
        child: FutureBuilder<UserModel>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final UserModel profile = snapshot.data ?? const UserModel(uid: '');
            final String rawMode = profile.shoppingMode == 'shop' ? 'shop' : 'home';
            final String mode = rawMode == 'shop' ? 'Shop Owner' : 'Home Shopping';
            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await Future.wait<dynamic>([_profileFuture, _ordersFuture]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      name: profile.displayName,
                      email: profile.email,
                      phone: profile.phoneNumber,
                      photoUrl: profile.photoUrl,
                      shoppingMode: mode,
                      onEdit: () async {
                        final result = await Navigator.pushNamed(context, AppRoutes.editProfile);
                        if (result == true && mounted) setState(_reload);
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(<Widget>[
                        _orderOverview(),
                        const SizedBox(height: 13),
                        ProfileShoppingModeCard(mode: rawMode, loading: _savingMode, onChanged: _changeShoppingMode),
                        const SizedBox(height: 20),
                        const _SectionTitle('YOUR FARM TO HOME'),
                        const SizedBox(height: 10),
                        ProfileMenuItem(icon: Icons.manage_accounts_rounded, title: 'Edit profile', subtitle: 'Name, phone and profile photo', onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile)),
                        ProfileMenuItem(icon: Icons.receipt_long_rounded, title: 'Orders & live tracking', subtitle: 'Track deliveries, invoices and reorder', onTap: () => Navigator.pushNamed(context, AppRoutes.orders)),
                        ProfileMenuItem(icon: Icons.location_on_rounded, title: 'Saved delivery addresses', subtitle: 'Home, shop and preferred locations', onTap: () => Navigator.pushNamed(context, AppRoutes.savedAddresses)),
                        ProfileMenuItem(icon: Icons.lock_person_rounded, title: 'Email & password login', subtitle: 'Set or reset your secure login password with OTP', onTap: _setLoginPassword),
                        const SizedBox(height: 18),
                        const _SectionTitle('PREFERENCES & SUPPORT'),
                        const SizedBox(height: 10),
                        ProfileMenuItem(icon: Icons.notifications_rounded, title: 'Notifications', subtitle: 'Order alerts and fresh deal preferences', onTap: () => Navigator.pushNamed(context, AppRoutes.notifications)),
                        ProfileMenuItem(icon: Icons.tune_rounded, title: 'App preferences', subtitle: 'Notifications, language and privacy', onTap: () => Navigator.pushNamed(context, AppRoutes.settings)),
                        ProfileMenuItem(icon: Icons.support_agent_rounded, title: 'Priority support', subtitle: 'Help with orders, refunds and payments', badge: 'LIVE', onTap: () => Navigator.pushNamed(context, AppRoutes.support)),
                        ProfileMenuItem(icon: Icons.shield_rounded, title: 'Privacy & security', subtitle: 'Account protection and data controls', onTap: () => Navigator.pushNamed(context, AppRoutes.privacy)),
                        const SizedBox(height: 18),
                        LogoutButton(onPressed: _logout, loading: _loggingOut),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (int index) {
          const routes = <String>[AppRoutes.home, AppRoutes.categories, AppRoutes.cart, AppRoutes.orders, AppRoutes.profile];
          if (index != 4) Navigator.pushReplacementNamed(context, routes[index]);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, letterSpacing: 1.15, fontWeight: FontWeight.w900));
}
