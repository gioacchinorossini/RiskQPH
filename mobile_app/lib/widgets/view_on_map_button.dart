import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../screens/common/hazard_map_screen.dart';

class ViewOnMapButton extends StatelessWidget {
  final List<dynamic>? residents;
  final Map<String, dynamic> locationData;
  final bool isPrimary;
  final String label;

  const ViewOnMapButton({
    super.key,
    this.residents,
    required this.locationData,
    this.isPrimary = false,
    this.label = "VIEW ON MAP",
  });

  @override
  Widget build(BuildContext context) {
    if (locationData['latitude'] == null || locationData['longitude'] == null) {
      return const SizedBox.shrink();
    }

    final Color themeColor = isPrimary ? Colors.red : const Color(0xFF006064);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => HazardMapScreen(
            residentsToRescue: residents?.cast<Map<String, dynamic>>().toList(),
            initialFocus: LatLng(
              (locationData['latitude'] as num).toDouble(),
              (locationData['longitude'] as num).toDouble(),
            ),
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(isPrimary ? 1.0 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(color: themeColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_rounded,
              size: 14,
              color: isPrimary ? Colors.white : themeColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : themeColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
