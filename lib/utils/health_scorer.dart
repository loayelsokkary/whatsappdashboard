import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/admin_analytics_provider.dart';
import '../theme/vivid_theme.dart';

/// A single factor contributing to the health score.
class HealthFactor {
  final String name;
  final double score; // 0-100
  final double weight;
  final String description;

  const HealthFactor({
    required this.name,
    required this.score,
    required this.weight,
    required this.description,
  });

  double get weighted => score * weight;
}

/// Overall health score for a client.
class ClientHealthScore {
  final String clientId;
  final String clientName;
  final int score; // 0-100
  final String grade; // A, B, C, D, F
  final Color gradeColor;
  final List<HealthFactor> factors;
  final List<String> recommendations;

  const ClientHealthScore({
    required this.clientId,
    required this.clientName,
    required this.score,
    required this.grade,
    required this.gradeColor,
    required this.factors,
    required this.recommendations,
  });
}

/// Computes health scores for clients.
class HealthScorer {
  const HealthScorer._();

  static const _coreFeatures = ['conversations', 'broadcasts', 'manager_chat'];
  static const _totalCoreFeatures = 3;

  // ── Grade mapping ───────────────────────────────────

  static String _grade(int score) {
    if (score >= 80) return 'A';
    if (score >= 60) return 'B';
    if (score >= 40) return 'C';
    if (score >= 20) return 'D';
    return 'F';
  }

  static Color gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return VividColors.statusSuccess;
      case 'B':
        return VividColors.cyan;
      case 'C':
        return VividColors.statusWarning;
      case 'D':
        return Colors.orange;
      case 'F':
        return VividColors.statusUrgent;
      default:
        return VividColors.statusUrgent;
    }
  }

  // ── Main entry point ────────────────────────────────

  /// Compute health scores for a list of clients.
  ///
  /// [activeUserCounts] maps clientId → number of users who logged in
  /// within the last 7 days. Pass an empty map if not available.
  ///
  /// [totalUserCounts] maps clientId → total user count.
  static List<ClientHealthScore> computeHealthScores({
    required List<Client> clients,
    VividCompanyAnalytics? analytics,
    Map<String, int> activeUserCounts = const {},
    Map<String, int> totalUserCounts = const {},
  }) {
    // Build lookup of client activities
    final activityMap = <String, ClientActivity>{};
    if (analytics != null) {
      for (final ca in analytics.allClientActivities) {
        activityMap[ca.clientId] = ca;
      }
    }

    return clients.map((client) {
      final activity = activityMap[client.id];
      return _scoreClient(
        client: client,
        activity: activity,
        activeUsers: activeUserCounts[client.id] ?? 0,
        totalUsers: totalUserCounts[client.id] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  // ── Per-client scoring ──────────────────────────────

  static ClientHealthScore _scoreClient({
    required Client client,
    ClientActivity? activity,
    required int activeUsers,
    required int totalUsers,
  }) {
    final factors = <HealthFactor>[];
    final recommendations = <String>[];

    // 1. Activity Recency (30%)
    final recencyScore = _activityRecency(activity?.lastActivity);
    factors.add(HealthFactor(
      name: 'Activity Recency',
      score: recencyScore,
      weight: 0.30,
      description: _recencyDescription(activity?.lastActivity),
    ));

    // 2. Message Volume (20%)
    final daysSinceOnboarding = DateTime.now().difference(client.createdAt).inDays;
    final volumeScore = _messageVolume(activity?.messageCount ?? 0, daysSinceOnboarding);
    factors.add(HealthFactor(
      name: 'Message Volume',
      score: volumeScore,
      weight: 0.20,
      description: '${activity?.messageCount ?? 0} messages over $daysSinceOnboarding days',
    ));

    // 3. Feature Adoption (20%) — based on 3 core features
    final enabledCoreCount = client.enabledFeatures.where((f) => _coreFeatures.contains(f)).length;
    final adoptionScore = (enabledCoreCount / _totalCoreFeatures) * 100;
    factors.add(HealthFactor(
      name: 'Feature Adoption',
      score: adoptionScore,
      weight: 0.20,
      description: '$enabledCoreCount of $_totalCoreFeatures core features enabled',
    ));

    // 4. User Engagement (15%)
    final engagementScore = totalUsers > 0 ? (activeUsers / totalUsers) * 100 : 0.0;
    factors.add(HealthFactor(
      name: 'User Engagement',
      score: engagementScore,
      weight: 0.15,
      description: totalUsers > 0
          ? '$activeUsers of $totalUsers users active in last 7 days'
          : 'No users assigned',
    ));

    // 5. Configuration Completeness (15%)
    final configScore = _configCompleteness(client);
    factors.add(HealthFactor(
      name: 'Config Completeness',
      score: configScore,
      weight: 0.15,
      description: _configDescription(client),
    ));

    // Weighted total
    final total = factors.fold<double>(0, (sum, f) => sum + f.weighted);
    final score = total.round().clamp(0, 100);
    final grade = _grade(score);

    // Recommendations
    if (recencyScore == 0) {
      recommendations.add('No activity in over a month \u2014 this client may have churned.');
    } else if (recencyScore < 30) {
      recommendations.add('No activity in over a week. Consider reaching out to check if they need help.');
    }

    if (adoptionScore < 60) {
      final unused = _unusedCoreFeatures(client);
      if (unused.isNotEmpty) {
        recommendations.add(
          'Only using $enabledCoreCount of $_totalCoreFeatures core features. Consider demonstrating ${unused.join(", ")}.',
        );
      }
    }

    if (configScore < 100 && client.enabledFeatures.isNotEmpty) {
      recommendations.add('Some features are enabled but not fully configured (missing phone or webhook).');
    }

    if (volumeScore < 20 && daysSinceOnboarding > 7) {
      recommendations.add('Very low message volume. The chatbot may not be promoted to their customers yet.');
    }

    if (engagementScore < 50 && totalUsers > 0) {
      recommendations.add('Less than half of their users are active. Some accounts may be unused.');
    }

    if (total.round() >= 80 && recommendations.isEmpty) {
      recommendations.add('This client is healthy and actively using the platform!');
    }

    return ClientHealthScore(
      clientId: client.id,
      clientName: client.name,
      score: score,
      grade: grade,
      gradeColor: gradeColor(grade),
      factors: factors,
      recommendations: recommendations,
    );
  }

  // ── Factor calculators ──────────────────────────────

  static double _activityRecency(DateTime? lastActivity) {
    if (lastActivity == null) return 0;
    final hours = DateTime.now().difference(lastActivity).inHours;
    if (hours < 24) return 100;
    if (hours < 72) return 80; // < 3 days
    if (hours < 168) return 60; // < 7 days
    if (hours < 720) return 30; // < 30 days
    return 0;
  }

  static String _recencyDescription(DateTime? lastActivity) {
    if (lastActivity == null) return 'No activity recorded';
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inHours < 24) return 'Active today';
    if (diff.inDays < 7) return 'Active ${diff.inDays} days ago';
    return 'Last seen ${diff.inDays} days ago';
  }

  static double _messageVolume(int messages, int days) {
    if (days <= 0) return messages > 0 ? 100 : 0;
    final perDay = messages / days;
    // Scale: 10+ msgs/day = 100, linear down to 0
    return (perDay / 10 * 100).clamp(0, 100);
  }

  static double _configCompleteness(Client client) {
    if (client.enabledFeatures.isEmpty) return 100; // nothing to configure
    int configured = 0;
    int total = 0;
    for (final f in client.enabledFeatures) {
      if (f == 'analytics') continue; // no config needed
      total++;
      if (_isFeatureFullyConfigured(client, f)) configured++;
    }
    if (total == 0) return 100;
    return (configured / total) * 100;
  }

  static bool _isFeatureFullyConfigured(Client client, String feature) {
    switch (feature) {
      case 'conversations':
        return _notEmpty(client.conversationsPhone) && _notEmpty(client.conversationsWebhookUrl);
      case 'broadcasts':
        return _notEmpty(client.broadcastsPhone) && _notEmpty(client.broadcastsWebhookUrl);
      case 'manager_chat':
        return _notEmpty(client.managerChatWebhookUrl);
      default:
        return true;
    }
  }

  static bool _notEmpty(String? v) => v != null && v.isNotEmpty;

  static String _configDescription(Client client) {
    if (client.enabledFeatures.isEmpty) return 'No features enabled';
    int configured = 0;
    int total = 0;
    for (final f in client.enabledFeatures) {
      if (f == 'analytics') continue;
      total++;
      if (_isFeatureFullyConfigured(client, f)) configured++;
    }
    if (total == 0) return 'All features configured';
    return '$configured of $total configurable features set up';
  }

  static List<String> _unusedCoreFeatures(Client client) {
    const displayNames = {
      'conversations': 'Conversations',
      'broadcasts': 'Broadcasts',
      'manager_chat': 'AI Assistant',
    };
    return _coreFeatures
        .where((f) => !client.enabledFeatures.contains(f))
        .map((f) => displayNames[f] ?? f)
        .toList();
  }
}
