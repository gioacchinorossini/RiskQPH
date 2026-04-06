import 'package:flutter/material.dart';

class MemberStatusIcon extends StatelessWidget {
  final String? relationship;
  final bool isSafe;
  final bool hasSOS;
  final bool isEmergencyActive;
  final bool isOnline; // For when disaster is not active: has location = online
  final bool isResponder;
  final double size;
  final Color? activeColor;

  const MemberStatusIcon({
    super.key,
    this.relationship,
    this.isSafe = false,
    this.hasSOS = false,
    this.isEmergencyActive = false,
    this.isOnline = false,
    this.isResponder = false,
    this.size = 24.0,
    this.activeColor,
  });

  static Color getStatusColor({
    bool isSafe = false,
    bool hasSOS = false,
    bool isEmergencyActive = false,
    bool isOnline = false,
    bool isResponder = false,
    Color? fallbackColor,
  }) {
    if (isResponder) return Colors.blue;
    if (!isEmergencyActive) {
      return isOnline ? Colors.green : (fallbackColor ?? Colors.grey);
    }
    // During Disaster
    if (isSafe) return Colors.green;
    if (hasSOS) return Colors.red;
    return Colors.orange; // Pending/At Risk in disaster
  }

  static IconData getRelationshipIcon(String? relationship) {
    if (relationship == null) return Icons.person_rounded;
    final rel = relationship.toLowerCase();
    if (rel.contains('spouse')) return Icons.favorite_rounded;
    if (rel.contains('child') || rel.contains('son') || rel.contains('daughter')) {
      return Icons.child_care_rounded;
    }
    if (rel.contains('father') ||
        rel.contains('mother') ||
        rel.contains('parent')) {
      return Icons.supervisor_account_rounded;
    }
    if (rel.contains('responder')) return Icons.security_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(
      isSafe: isSafe,
      hasSOS: hasSOS,
      isEmergencyActive: isEmergencyActive,
      isOnline: isOnline,
      isResponder: isResponder,
      fallbackColor: activeColor,
    );

    return Icon(
      getRelationshipIcon(relationship),
      color: color,
      size: size,
    );
  }
}

class MemberMarker extends StatelessWidget {
  final String? relationship;
  final bool isSafe;
  final bool hasSOS;
  final bool isEmergencyActive;
  final bool isOnline;
  final bool isResponder;
  final double size;
  final bool isHighlighted;
  final Color? activeColor;

  const MemberMarker({
    super.key,
    this.relationship,
    this.isSafe = false,
    this.hasSOS = false,
    this.isEmergencyActive = false,
    this.isOnline = false,
    this.isResponder = false,
    this.size = 24.0,
    this.isHighlighted = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = MemberStatusIcon.getStatusColor(
      isSafe: isSafe,
      hasSOS: hasSOS,
      isEmergencyActive: isEmergencyActive,
      isOnline: isOnline,
      isResponder: isResponder,
      fallbackColor: activeColor,
    );

    final borderColor = isHighlighted ? Colors.teal : color;
    final borderWidth = isHighlighted ? 3.5 : 2.0;
    final glowColor = isHighlighted ? Colors.teal.withOpacity(0.45) : color.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: isHighlighted ? 12 : 8,
            color: glowColor,
          ),
        ],
      ),
      child: MemberStatusIcon(
        relationship: relationship,
        isSafe: isSafe,
        hasSOS: hasSOS,
        isEmergencyActive: isEmergencyActive,
        isOnline: isOnline,
        isResponder: isResponder,
        size: size,
        activeColor: activeColor,
      ),
    );
  }
}
class MemberStatusBubble extends StatelessWidget {
  final bool isSafe;
  final bool hasSOS;
  final bool isEmergencyActive;
  final bool isOnline;
  final bool isResponder;
  final String? label;
  final Color? fallbackColor;

  const MemberStatusBubble({
    super.key,
    this.isSafe = false,
    this.hasSOS = false,
    this.isEmergencyActive = false,
    this.isOnline = false,
    this.isResponder = false,
    this.label,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color markerColor = MemberStatusIcon.getStatusColor(
      isSafe: isSafe,
      hasSOS: hasSOS,
      isEmergencyActive: isEmergencyActive,
      isOnline: isOnline,
      isResponder: isResponder,
      fallbackColor: fallbackColor,
    );

    String markerLabel = label ?? '';
    if (markerLabel.isEmpty) {
      if (isResponder) {
        markerLabel = 'RESPONDER';
      } else if (!isEmergencyActive) {
        markerLabel = 'CONNECTED';
      } else {
        if (isSafe) markerLabel = 'SAFE';
        else if (hasSOS) markerLabel = 'SOS';
        else markerLabel = 'PENDING';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: markerColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Colors.black26,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        markerLabel.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
