import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final auth = context.read<AuthService>();
    if (!auth.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.listUsers(auth.token!);
      if (response['success'] == true && response['users'] is List) {
        _users = List<Map<String, dynamic>>.from(response['users']);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load users')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final auth = context.read<AuthService>();
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final currentRole = user['role'] ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';

    // Can't change own role
    if (userId == auth.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't change your own role")),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: Text('Change ${user['name']} from $currentRole to $newRole?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiService.changeUserRole(auth.token!, userId, newRole);
      if (response['success'] == true) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user['name']} is now $newRole')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Failed')),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final auth = context.read<AuthService>();
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';

    // Can't delete self
    if (userId == auth.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't delete your own account")),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Permanently delete "${user['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteUser(auth.token!, userId);
      if (response['success'] == true) _loadUsers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
                      final name = user['name'] ?? '';
                      final email = user['email'] ?? '';
                      final role = user['role'] ?? 'user';
                      final createdAt = user['created_at'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: UserAvatar(userId: userId, userName: name, radius: 22),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: role == 'admin' ? Colors.purple.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: role == 'admin' ? Colors.purple : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'role') _changeRole(user);
                              if (value == 'delete') _deleteUser(user);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'role',
                                child: Text(role == 'admin' ? 'Make User' : 'Make Admin'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
