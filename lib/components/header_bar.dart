import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/auth.dart';

class HeaderBar extends StatelessWidget {
  HeaderBar({super.key});

  final supabaseAuth = SupabaseAuth();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Stack(
          children: [
            // 居中的 Logo
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Image.asset(
                  "web/icons/geoprofs.png",
                  height: 50,
                ),
              ),
            ),

            // 右侧登录/头像区域
            Align(
              alignment: Alignment.centerRight,
              child: FutureBuilder(
                future: Future.value(Supabase.instance.client.auth.currentUser),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8.0, top: 8.0),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontFamily: 'KaushanScript',
                          ),
                        ),
                      ),
                    );
                  } else {
                    final avatarUrl = user.userMetadata?['avatar_url'] as String?;
                    final defaultAvatar =
                        'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                avatarUrl?.isNotEmpty == true ? avatarUrl! : defaultAvatar,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          color: Colors.black,
                          onPressed: () => supabaseAuth.logoutUser(),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}