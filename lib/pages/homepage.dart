import 'package:flutter/material.dart';
import 'package:geoprof/components/navbar.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<Homepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEE6055),Color(0xFFFFFFFF)],
            stops: [0.25, 1.0],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: Image.asset("web/icons/geoprofs.png", height: 50,),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: Center(),
            ),
          ],
        ),
      ),
      floatingActionButton: const Navbar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
