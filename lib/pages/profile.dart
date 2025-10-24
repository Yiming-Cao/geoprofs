import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geoprof/components/protected_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  
  @override
  Widget build(BuildContext context) {
    return ProtectedRoute(
      child: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) 
        ? const MobileLayout() : const DesktopLayout(),
    );
  }
}


final supabase = Supabase.instance.client;

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Profile Page',
                style: TextStyle(fontSize: 24),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushNamed(context, '/');
                },
              ),
            ],
          ),
        ),
    );
  }
}

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  void _showAccountDialog(BuildContext context, dynamic user) {
    final usernameController = TextEditingController(text: user?.userMetadata?['username'] ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final showConfirm = passwordController.text.isNotEmpty;
            return AlertDialog(
              title: const Text('Account Settings'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (showConfirm)
                      TextField(
                        controller: confirmPasswordController,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        obscureText: true,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final supabase = Supabase.instance.client;
                    if (passwordController.text.isNotEmpty &&
                        passwordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match!')),
                      );
                      return;
                    }
                    // update username
                    if (usernameController.text.isNotEmpty &&
                        usernameController.text != user?.userMetadata?['display_name']) {
                      await supabase.auth.updateUser(
                        UserAttributes(
                          data: {'display_name': usernameController.text},
                        ),
                      );
                    }
                    // update email
                    if (emailController.text.isNotEmpty &&
                        emailController.text != user?.email) {
                      await supabase.auth.updateUser(
                        UserAttributes(email: emailController.text),
                      );
                    }
                    // update password
                    if (passwordController.text.isNotEmpty) {
                      await supabase.auth.updateUser(
                        UserAttributes(password: passwordController.text),
                      );
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account updated!')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final defaultAvatar =
        'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Column(
          children: [
            HeaderBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(16.0),
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundImage: NetworkImage(
                                      avatarUrl?.isNotEmpty == true ? avatarUrl! : defaultAvatar,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.userMetadata?['display_name'] ?? 'User Name',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        user?.email ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              const Divider(),
                              _SidebarItem(icon: Icons.home, label: 'Home'),
                              _SidebarItem(icon: Icons.folder, label: 'Work'),
                              _SidebarItem(icon: Icons.message, label: 'Messages'),
                            ]
                          ),
                        ),
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:[
                              const Text(
                                'Management',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SidebarItem(
                                icon: Icons.settings, 
                                label: 'Settings',
                                onTap: () => _showAccountDialog(context, user),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Profile Page Content Area',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Navbar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SidebarItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}