import '../models/models.dart';
import 'supabase_service.dart';

/// Manages admin impersonation / "View as Client" mode.
///
/// Stores the original admin user, swaps ClientConfig to the target client,
/// and provides a global [isImpersonating] flag that UI components check
/// to enforce read-only behavior.
class ImpersonateService {
  ImpersonateService._();

  static AppUser? _originalAdmin;
  static Client? _targetClient;

  /// Whether we are currently in impersonation mode.
  static bool get isImpersonating => _originalAdmin != null;

  /// The client being impersonated (null when not impersonating).
  static Client? get targetClient => _targetClient;

  /// The original admin user (null when not impersonating).
  static AppUser? get originalAdmin => _originalAdmin;

  /// Start impersonating [client]. Saves current admin state and swaps
  /// ClientConfig to the target client context.
  static Future<void> startImpersonation(Client client) async {
    if (_originalAdmin != null) return; // Already impersonating

    _originalAdmin = ClientConfig.currentUser;
    _targetClient = client;

    final admin = _originalAdmin!;
    final tempUser = AppUser(
      id: admin.id,
      email: admin.email,
      name: '${admin.name} (viewing ${client.name})',
      role: UserRole.admin,
      clientId: client.id,
      createdAt: DateTime.now(),
    );

    ClientConfig.enterPreview(client, tempUser);

    // Log impersonation start
    await SupabaseService.instance.logActivity(
      clientId: client.id,
      userId: admin.id,
      userName: admin.name,
      userEmail: admin.email,
      actionType: ActionType.impersonationStart.value,
      description: 'Started viewing as ${client.name}',
      metadata: {
        'target_client_id': client.id,
        'target_client_name': client.name,
        'target_client_slug': client.slug,
      },
    );
  }

  /// Stop impersonating. Restores original admin state and logs the action.
  static Future<void> stopImpersonation() async {
    if (_originalAdmin == null) return;

    final admin = _originalAdmin!;
    final client = _targetClient;

    ClientConfig.exitPreview();

    // Log impersonation end
    if (client != null) {
      await SupabaseService.instance.logActivity(
        clientId: client.id,
        userId: admin.id,
        userName: admin.name,
        userEmail: admin.email,
        actionType: ActionType.impersonationEnd.value,
        description: 'Stopped viewing as ${client.name}',
        metadata: {
          'target_client_id': client.id,
          'target_client_name': client.name,
        },
      );
    }

    _originalAdmin = null;
    _targetClient = null;
  }
}
