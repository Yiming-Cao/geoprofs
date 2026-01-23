import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = -1;
  final supabase = Supabase.instance.client;

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isManager = false;
  bool _isOfficeManager = false;
  bool _hasNotifications = false;
  Future<void>? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRole();
    _checkNotifications();
    
    // 定期检查通知（每1秒）
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _notificationTimer = Future.doWhile(() async {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            await _checkNotifications();
          }
          return mounted;
        });
      }
    });
    
    // 监听登录/登出变化
    supabase.auth.onAuthStateChange.listen((_) {
      _checkAuthAndRole();
      _checkNotifications();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAuthAndRole() async {
    final user = supabase.auth.currentUser;

    setState(() {
      _isLoggedIn = user != null;
    });

    if (user == null) {
      setState(() => _isAdmin = false);
      setState(() {
        _isOfficeManager = false;
      });
      return;
    }

    try {
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', user.id)
          .maybeSingle();

      final bool isAdmin = response != null && (response['role'] as String?) == 'admin';
      final bool isManager = response != null && (response['role'] as String?) == 'manager';
      final bool isOfficeManager = response != null && (response['role'] as String?) == 'office_manager';

      if (mounted) {
        setState(() => _isAdmin = isAdmin);
        setState(() => _isManager = isManager);
        setState(() => _isOfficeManager = isOfficeManager);
      }
    } catch (e) {
      // Als er iets misgaat → geen admin rechten tonen
      if (mounted) {
        setState(() => _isAdmin = false);
        setState(() => _isOfficeManager = false);
      }
    }
  }

  Future<void> _checkNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _hasNotifications = false);
      return;
    }

    try {
      // 查询当前用户的未确认通知（is_confirmed=false，且不是pending状态）
      final response = await supabase
          .from('verlof')
          .select()
          .eq('user_id', user.id)
          .neq('verlof_state', 'pending')
          .eq('is_confirmed', false)
          .limit(1);

      bool has = false;
      if (response is List && response.isNotEmpty) {
        has = true;
      }

      // Additionally: if this user is a manager or office manager, check for pending team requests
      bool managerHas = false;
      try {
        if (_isOfficeManager) {
          final resp = await supabase
              .rpc('get_verlof_for_managers_only', params: {'current_user_id': user.id});
          if (resp is List && resp.isNotEmpty) managerHas = true;
        } else if (_isManager) {
          final resp = await supabase
              .from('verlof')
              .select('id')
              .eq('verlof_state', 'pending')
              .limit(1);
          if (resp is List && resp.isNotEmpty) managerHas = true;
        }
      } catch (e) {
        debugPrint('Check manager pending failed: $e');
      }

      final result = has || managerHas;
      if (mounted) setState(() => _hasNotifications = result);
    } catch (e) {
      debugPrint('Check notifications error: $e');
      // 忽略错误，保持notifications为false
      if (mounted) setState(() => _hasNotifications = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    final route = _getRouteForIndex(index);
    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }

  String? _getRouteForIndex(int index) {
    return switch (index) {
      0 => '/verlof',
      1 => _isLoggedIn ? '/profile' : '/login',
      2 => '/',
      3 => '/mail',
      4 => '/notifications',
      5 => '/admin',
      6 => '/officemanager',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width.clamp(280, 340),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.calendar_today, 0),
          _buildNavItem(Icons.person, 1),

          // Home knop (rood)
          SizedBox(
            width: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEE6055),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.home, size: 24),
                color: Colors.white,
                onPressed: () => _onItemTapped(2),
              ),
            ),
          ),

          _buildNavItem(Icons.mail, 3),
          _buildNavItem(Icons.notifications, 4),

          // ADMIN ICOON → ALLEEN VOOR ADMINS (zelfde check als admin.dart)
          if (_isAdmin)
            _buildNavItem(Icons.admin_panel_settings, 5),
          // Office Manager 图标 → 仅限办公室经理
          if (_isOfficeManager)
            _buildNavItem(Icons.business, 6),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    // For notifications, we show a small red dot when there are notifications
    if (icon == Icons.notifications) {
      return SizedBox(
        width: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 24),
              color: _selectedIndex == index ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(index),
            ),
            if (_hasNotifications)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 24),
        color: _selectedIndex == index ? const Color(0xFFEE6055) : Colors.white,
        onPressed: () => _onItemTapped(index),
      ),
    );
  }
}