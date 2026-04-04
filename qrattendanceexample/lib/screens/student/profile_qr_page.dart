import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileQRPage extends StatelessWidget {
  const ProfileQRPage({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: height * 0.8, // 80% of screen
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final shrinkOffset = constraints.maxHeight;
                final isCollapsed = shrinkOffset <= height * 0.3 + kToolbarHeight;

                return FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  centerTitle: false,
                  title: isCollapsed
                      ? Row(
                          children: [
                            QrImageView(
                              data: "USER_QR_CODE",
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text("John Doe", style: TextStyle(fontSize: 16, color: Colors.black)),
                                Text("Year 2", style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ],
                        )
                      : null,
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      QrImageView(
                        data: "USER_QR_CODE",
                        size: 200,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "John Doe",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "Year 2",
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                "Scroll content goes here...",
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}
