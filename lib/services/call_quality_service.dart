import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Network Quality Levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
}

/// Call Quality Service
/// Monitors WebRTC statistics and calculates quality metrics
class CallQualityService {
  static final CallQualityService _instance = CallQualityService._internal();
  factory CallQualityService() => _instance;
  CallQualityService._internal();

  Timer? _statsTimer;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, Function(Map<String, dynamic>)> _qualityCallbacks = {};

  /// Start monitoring call quality for a peer connection
  void startMonitoring(String callId, RTCPeerConnection peerConnection) {
    _peerConnections[callId] = peerConnection;
    
    // Monitor stats every 2 seconds
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _collectStats(callId, peerConnection);
    });
  }

  /// Stop monitoring call quality
  void stopMonitoring(String callId) {
    _peerConnections.remove(callId);
    _qualityCallbacks.remove(callId);
    if (_peerConnections.isEmpty) {
      _statsTimer?.cancel();
      _statsTimer = null;
    }
  }

  /// Set quality callback for a call
  void onQualityUpdate(String callId, Function(Map<String, dynamic>) callback) {
    _qualityCallbacks[callId] = callback;
  }

  /// Collect WebRTC statistics
  Future<void> _collectStats(String callId, RTCPeerConnection peerConnection) async {
    try {
      final stats = await peerConnection.getStats();
      final qualityMetrics = _calculateQualityMetrics(stats);
      
      // Notify callback if registered
      final callback = _qualityCallbacks[callId];
      if (callback != null) {
        callback(qualityMetrics);
      }
      
      Log.i('Call quality: ${qualityMetrics['networkQuality']}, Score: ${qualityMetrics['connectionScore']}', 'CALL_QUALITY');
    } catch (e) {
      Log.e('Error collecting call stats', 'CALL_QUALITY', e);
    }
  }

  /// Calculate quality metrics from WebRTC stats
  Map<String, dynamic> _calculateQualityMetrics(dynamic stats) {
    double totalBytesReceived = 0;
    double totalBytesSent = 0;
    double totalPacketsLost = 0;
    double totalPackets = 0;
    double totalJitter = 0;
    double totalRtt = 0;
    int audioTracks = 0;
    int videoTracks = 0;

    stats.forEach((key, value) {
      // Audio/Video stats
      if (value.type == 'inbound-rtp' || value.type == 'outbound-rtp') {
        if (value.mediaType == 'audio') {
          audioTracks++;
        } else if (value.mediaType == 'video') {
          videoTracks++;
        }

        totalBytesReceived += (value.bytesReceived ?? 0).toDouble();
        totalBytesSent += (value.bytesSent ?? 0).toDouble();
        totalPacketsLost += (value.packetsLost ?? 0).toDouble();
        totalPackets += (value.packetsReceived ?? value.packetsSent ?? 0).toDouble();
        totalJitter += (value.jitter ?? 0).toDouble();
      }

      // Connection stats
      if (value.type == 'candidate-pair' && value.state == 'succeeded') {
        totalRtt += (value.currentRoundTripTime ?? 0).toDouble();
      }
    });

    // Calculate metrics
    final packetLossRate = totalPackets > 0 ? (totalPacketsLost / totalPackets) * 100 : 0;
    final avgJitter = (audioTracks + videoTracks) > 0 ? totalJitter / (audioTracks + videoTracks) : 0;
    final avgRtt = totalRtt > 0 ? totalRtt : 0;
    final bandwidthUsed = (totalBytesReceived + totalBytesSent) / 1024 / 1024; // MB

    // Determine network quality
    NetworkQuality networkQuality = NetworkQuality.excellent;
    if (packetLossRate > 5 || avgJitter > 50 || avgRtt > 300) {
      networkQuality = NetworkQuality.poor;
    } else if (packetLossRate > 2 || avgJitter > 30 || avgRtt > 200) {
      networkQuality = NetworkQuality.fair;
    } else if (packetLossRate > 1 || avgJitter > 20 || avgRtt > 150) {
      networkQuality = NetworkQuality.good;
    }

    // Calculate connection score (0-100)
    double connectionScore = 100;
    connectionScore -= (packetLossRate * 10).clamp(0, 50); // Packet loss penalty
    connectionScore -= (avgJitter / 2).clamp(0, 20); // Jitter penalty
    connectionScore -= (avgRtt / 10).clamp(0, 30); // RTT penalty
    connectionScore = connectionScore.clamp(0, 100);

    return {
      'networkQuality': networkQuality.toString().split('.').last,
      'connectionScore': connectionScore.round(),
      'packetLossRate': packetLossRate.toStringAsFixed(2),
      'avgJitter': avgJitter.toStringAsFixed(2),
      'avgRtt': avgRtt.toStringAsFixed(2),
      'bandwidthUsed': bandwidthUsed.toStringAsFixed(2),
      'audioTracks': audioTracks,
      'videoTracks': videoTracks,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get quality level description
  static String getQualityDescription(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
    }
  }

  /// Dispose resources
  void dispose() {
    _statsTimer?.cancel();
    _peerConnections.clear();
    _qualityCallbacks.clear();
  }
}

