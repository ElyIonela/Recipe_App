import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Circular user avatar with LRU cache.
/// Loads profile picture from Ubex API, falls back to name initial.
class UserAvatar extends StatefulWidget {
  final String userId;
  final String userName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.userName,
    this.radius = 20,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  static final LinkedHashMap<String, String?> _cache = LinkedHashMap();
  static const int _maxCacheSize = 100;
  static final Map<String, Future<String?>> _pendingRequests = {};

  String? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    final key = widget.userId;
    if (key.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Check cache
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key);
      _cache[key] = value;
      setState(() {
        _imageData = value;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      _pendingRequests[key] ??= _fetchAvatar(key);
      final result = await _pendingRequests[key];
      _pendingRequests.remove(key);

      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = result;

      if (mounted) {
        setState(() {
          _imageData = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      _pendingRequests.remove(key);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static Future<String?> _fetchAvatar(String userId) async {
    try {
      final response = await ApiService.getProfilePicture(userId);
      if (response['success'] == true && response['profile_picture'] != null) {
        return response['profile_picture'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.orange.shade100,
        child: SizedBox(
          width: widget.radius,
          height: widget.radius,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_imageData != null) {
      try {
        String raw = _imageData!;
        if (raw.contains(',')) raw = raw.split(',').last;
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: MemoryImage(base64Decode(raw)),
        );
      } catch (_) {}
    }

    // Fallback: initial on colored background
    final initial =
        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.orange.shade200,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: widget.radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
