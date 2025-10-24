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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Image.asset(
                    "web/icons/geoprofs.png",
                    height: 50,
                  ),
                ),
              ),
            ),
            FutureBuilder(
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
                          fontFamily: 'KaushanScript', // 使用自定义字体

                        ),
                      ),
                    ),
                  );
                } else {
                  final avatarUrl = user.userMetadata?['avatar_url'] as String?;
                  final defaultAvatar =
                      'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';
                  return Row(
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
          ],
        ),
      ),
    );
  }
}