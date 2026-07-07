import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class IssueEntity extends Equatable {
  final String id;
  final String category;
  final String descriptionTa;
  final String descriptionEn;
  final double latitude;
  final double longitude;
  final String? geographyId;
  final String? photoUrl;
  final String? verificationPhotoUrl;
  final String status;
  final String? assignedVolunteerId;
  final String? reportedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IssueEntity({
    required this.id,
    required this.category,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.latitude,
    required this.longitude,
    this.geographyId,
    this.photoUrl,
    this.verificationPhotoUrl,
    required this.status,
    this.assignedVolunteerId,
    this.reportedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  String displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  // ── Category helpers ──────────────────────────────────────────────────────
  String get categoryEmoji {
    switch (category) {
      case 'ROAD_TRAFFIC':
        return '🛣️';
      case 'POWER_CUT':
        return '⚡';
      case 'WATER':
        return '💧';
      case 'OTHER':
      default:
        return '📋';
    }
  }

  String categoryLabel(String lang) {
    switch (category) {
      case 'ROAD_TRAFFIC':
        return lang == 'ta' ? 'சாலை / போக்குவரத்து' : 'Road/Traffic';
      case 'POWER_CUT':
        return lang == 'ta' ? 'மின் தடை' : 'Power Cut';
      case 'WATER':
        return lang == 'ta' ? 'நீர்' : 'Water';
      case 'OTHER':
      default:
        return lang == 'ta' ? 'மற்றவை' : 'Other';
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  Color get statusColor {
    switch (status) {
      case 'NEW':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.indigo;
      case 'UNDER_REVIEW':
        return Colors.amber;
      case 'ESCALATED':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(String lang) {
    switch (status) {
      case 'NEW':
        return lang == 'ta' ? 'புதியது' : 'New';
      case 'ASSIGNED':
        return lang == 'ta' ? 'ஒதுக்கப்பட்டது' : 'Assigned';
      case 'UNDER_REVIEW':
        return lang == 'ta' ? 'பரிசீலனையில்' : 'Under Review';
      case 'ESCALATED':
        return lang == 'ta' ? 'மேல்முறையீடு' : 'Escalated';
      case 'RESOLVED':
        return lang == 'ta' ? 'தீர்க்கப்பட்டது' : 'Resolved';
      case 'CLOSED':
        return lang == 'ta' ? 'மூடப்பட்டது' : 'Closed';
      case 'REJECTED':
        return lang == 'ta' ? 'நிராகரிக்கப்பட்டது' : 'Rejected';
      default:
        return status;
    }
  }

  @override
  List<Object?> get props => [id, category, status, createdAt, updatedAt];
}

/// Selectable status values for filter chips, in display order.
const List<String> kIssueStatuses = [
  'NEW',
  'ASSIGNED',
  'UNDER_REVIEW',
  'ESCALATED',
  'RESOLVED',
  'CLOSED',
  'REJECTED',
];

Color issueStatusColor(String status) {
  switch (status) {
    case 'NEW':
      return Colors.blue;
    case 'ASSIGNED':
      return Colors.indigo;
    case 'UNDER_REVIEW':
      return Colors.amber;
    case 'ESCALATED':
      return Colors.orange;
    case 'RESOLVED':
      return Colors.green;
    case 'CLOSED':
      return Colors.grey;
    case 'REJECTED':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String issueStatusLabel(String status, String lang) {
  switch (status) {
    case 'NEW':
      return lang == 'ta' ? 'புதியது' : 'New';
    case 'ASSIGNED':
      return lang == 'ta' ? 'ஒதுக்கப்பட்டது' : 'Assigned';
    case 'UNDER_REVIEW':
      return lang == 'ta' ? 'பரிசீலனையில்' : 'Under Review';
    case 'ESCALATED':
      return lang == 'ta' ? 'மேல்முறையீடு' : 'Escalated';
    case 'RESOLVED':
      return lang == 'ta' ? 'தீர்க்கப்பட்டது' : 'Resolved';
    case 'CLOSED':
      return lang == 'ta' ? 'மூடப்பட்டது' : 'Closed';
    case 'REJECTED':
      return lang == 'ta' ? 'நிராகரிக்கப்பட்டது' : 'Rejected';
    default:
      return status;
  }
}
