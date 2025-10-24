import 'package:flutter/material.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Column(
          children: [
            HeaderBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16.0),
                  Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    color: Colors.white,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Welcome to GeoProfs! With this app you can easily plan your days off',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(),
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