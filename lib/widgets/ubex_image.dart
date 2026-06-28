import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Widget for displaying images stored in Ubex file storage.
/// Detects internal Ubex paths (starting with /) and loads them via API as base64.
/// Uses a static LRU cache (max 100 images) with request deduplication.
class UbexImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UbexImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<UbexImage> createState() => _UbexImageState();
}

class _UbexImageState extends State<UbexImage> {
  // Static LRU cache shared across all instances
  static final LinkedHashMap<String, String> _cache = LinkedHashMap();
  static const int _maxCacheSize = 100;
  // Track in-flight requests to deduplicate
  static final Map<String, Future<String?>> _pendingRequests = {};

  String? _base64Data;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(UbexImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  bool _isUbexPath(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('/');
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    // If it's a regular URL (not Ubex path), just use it directly
    if (!_isUbexPath(url)) {
      setState(() {
        _isLoading = false;
        _base64Data = null;
      });
      return;
    }

    // Check cache
    if (_cache.containsKey(url)) {
      // Move to end (most recently used)
      final value = _cache.remove(url)!;
      _cache[url] = value;
      setState(() {
        _base64Data = value;
        _isLoading = false;
      });
      return;
    }

    // Deduplicate requests
    setState(() => _isLoading = true);

    try {
      _pendingRequests[url] ??= _fetchFromUbex(url);
      final result = await _pendingRequests[url];
      _pendingRequests.remove(url);

      if (result != null && mounted) {
        // Add to cache, evict oldest if necessary
        if (_cache.length >= _maxCacheSize) {
          _cache.remove(_cache.keys.first);
        }
        _cache[url] = result;

        setState(() {
          _base64Data = result;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      _pendingRequests.remove(url);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  static Future<String?> _fetchFromUbex(String path) async {
    try {
      // Strip query params for the API call
      final cleanPath = path.contains('?') ? path.split('?').first : path;
      final response = await ApiService.getRecipeImage(cleanPath);
      if (response['success'] == true && response['image'] != null) {
        return response['image'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ??
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_hasError) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ??
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }

    // Regular URL - use NetworkImage
    if (!_isUbexPath(widget.imageUrl)) {
      return Image.network(
        widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) =>
            widget.errorWidget ??
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }

    // Base64 image from Ubex
    if (_base64Data != null) {
      try {
        // Handle data URI format: data:image/png;base64,XXXX
        String raw = _base64Data!;
        if (raw.contains(',')) {
          raw = raw.split(',').last;
        }
        return Image.memory(
          base64Decode(raw),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) =>
              widget.errorWidget ??
              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        );
      } catch (_) {
        return widget.errorWidget ??
            const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    }

    return widget.errorWidget ??
        const Center(child: Icon(Icons.broken_image, color: Colors.grey));
  }
}
