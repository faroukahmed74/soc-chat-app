import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import '../services/webrtc_call_service.dart';
import '../services/call_types.dart';
import '../services/local_auth_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';
import '../services/call_quality_service.dart';
import '../services/call_controls_service.dart';
import '../services/ringtone_service.dart';
import '../widgets/call_forward_dialog.dart';
import '../widgets/call_transfer_dialog.dart';
import '../config/database_config.dart';
import '../main.dart'; // For ActiveCallTracker

/// Call Screen - Handles incoming, outgoing, and active calls with WebRTC
class CallScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroupChat;
  final List<String>? participantIds;
  final List<String>? participantNames;
  final CallType callType;
  final CallDirection direction;
  final String? callId; // For joining existing calls

  const CallScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroupChat,
    this.participantIds,
    this.participantNames,
    required this.callType,
    this.direction = CallDirection.outgoing,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallState _callState;
  final _callService = WebRTCCallService();
  String? _currentUserId;
  String? _currentUserName;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  
  // WebRTC video renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isSpeakerOn = false; // Speaker mode (false = earpiece, true = speaker)
  
  // Ringtone and vibration
  AudioPlayer? _ringtonePlayer;
  Timer? _vibrationTimer;
  bool _isRinging = false;
  final _ringtoneService = RingtoneService();
  
  // Call quality monitoring
  final _qualityService = CallQualityService();
  Map<String, dynamic>? _qualityMetrics;
  String? _currentCallId;
  
  // Call controls
  final _callControlsService = CallControlsService();
  bool _isScreenSharing = false;
  bool _isCallHeld = false;
  final Map<String, bool> _participantMuted = {}; // Track muted participants
  bool _isCallHost = false; // Whether current user is the call host
  bool _isClosing = false; // Prevent duplicate navigation pops

  @override
  void initState() {
    super.initState();
    print('🔵 CallScreen initState called');
    _callState = widget.direction == CallDirection.incoming 
        ? CallState.ringing 
        : CallState.initiating;
    print('🔵 CallScreen initialized: direction=${widget.direction}, callType=${widget.callType}, callId=${widget.callId}');
    print('🔵 Chat: ${widget.chatId}, Participants: ${widget.participantIds?.length ?? 0}');
    Log.i('📞 CallScreen initialized: direction=${widget.direction}, callType=${widget.callType}, callId=${widget.callId}', 'CALL_SCREEN');
    Log.i('📞 Chat: ${widget.chatId}, Participants: ${widget.participantIds?.length ?? 0}', 'CALL_SCREEN');
    
    // Start ringtone and vibration for incoming calls
    if (widget.direction == CallDirection.incoming) {
      _startRinging();
    }
    
    _initializeCall();
  }
  
  /// Start ringtone and vibration for incoming calls
  Future<void> _startRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    
    try {
      // Start vibration pattern (vibrate for 500ms, pause for 500ms, repeat)
      if (await Vibration.hasVibrator() ?? false) {
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
          // Check if still ringing before vibrating (prevent vibration after call accepted)
          if (!_isRinging) {
            print('🔔 [VIBRATION_TIMER] _isRinging is false, cancelling timer');
            timer.cancel();
            _vibrationTimer = null;
            Vibration.cancel(); // Ensure vibration is cancelled
            return;
          }
          // Double-check _isRinging before vibrating
          if (_isRinging) {
            Vibration.vibrate(duration: 500);
          } else {
            timer.cancel();
            _vibrationTimer = null;
            Vibration.cancel();
          }
        });
        print('🔔 Vibration started');
        Log.i('Vibration started for incoming call', 'CALL_SCREEN');
      }
      
      // Play custom ringtone if available, otherwise use default
      await _ringtoneService.playRingtone();
      
      print('🔔 Ringtone/vibration started for incoming call');
      Log.i('Ringtone/vibration started for incoming call', 'CALL_SCREEN');
    } catch (e) {
      print('❌ Error starting ringtone/vibration: $e');
      Log.e('Error starting ringtone/vibration', 'CALL_SCREEN', e);
    }
  }
  
  /// Stop ringtone and vibration
  Future<void> _stopRinging() async {
    print('🔔 [STOP_RINGING] Called, _isRinging: $_isRinging');
    
    // Set _isRinging to false FIRST to prevent timer callback from vibrating
    _isRinging = false;
    
    // Cancel vibration timer IMMEDIATELY
    if (_vibrationTimer != null) {
      print('🔔 [STOP_RINGING] Cancelling vibration timer');
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
    }
    
    // Cancel vibration immediately (try multiple times with different methods)
    for (int i = 0; i < 8; i++) {
      try {
        // Method 1: Cancel vibration
        await Vibration.cancel();
        
        // Method 2: Vibrate with pattern [0] to stop any ongoing vibration
        try {
          await Vibration.vibrate(pattern: [0]);
        } catch (e) {
          // Some devices don't support pattern, ignore
        }
        
        print('🔔 [STOP_RINGING] Vibration cancelled (attempt ${i + 1})');
      } catch (e) {
        print('⚠️ [STOP_RINGING] Error cancelling vibration (attempt ${i + 1}): $e');
      }
      if (i < 7) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
    
    // Stop ringtone (always stop, even if _isRinging was already false)
    try {
      // Stop custom ringtone
      await _ringtoneService.stopRingtone();
      print('🔔 [STOP_RINGING] Ringtone service stopped');
      
      // Stop and dispose ringtone player (legacy)
      try {
        await _ringtonePlayer?.stop();
        await _ringtonePlayer?.dispose();
        _ringtonePlayer = null;
        print('🔔 [STOP_RINGING] Ringtone player stopped and disposed');
      } catch (e) {
        print('⚠️ [STOP_RINGING] Error stopping ringtone player: $e');
      }
      
      print('🔔 [STOP_RINGING] Ringtone and vibration stopped successfully');
      Log.i('Ringtone and vibration stopped', 'CALL_SCREEN');
    } catch (e) {
      print('❌ [STOP_RINGING] Error stopping ringtone/vibration: $e');
      Log.e('Error stopping ringtone/vibration', 'CALL_SCREEN', e);
    }
  }

  Future<void> _initializeCall() async {
    try {
      print('🔵 _initializeCall started');
      Log.i('📞 Initializing call screen...', 'CALL_SCREEN');
      // Initialize video renderers
      print('🔵 Initializing video renderer...');
      await _localRenderer.initialize();
      print('🔵 Video renderer initialized');
      Log.i('📞 Video renderer initialized', 'CALL_SCREEN');

      // Get current user info
      print('🔵 Getting current user...');
      Map<String, dynamic>? user = await LocalAuthService.getCurrentUser();
      
      // If getCurrentUser returns null, try alternative methods
      if (user == null) {
        print('🔵 getCurrentUser returned null, trying alternative methods...');
        final userId = await LocalAuthService.getCurrentUserIdAsync();
        if (userId != null) {
          print('🔵 Found user ID via getCurrentUserIdAsync: $userId');
          user = {
            'id': userId,
            'name': 'User',
            'email': '',
          };
          } else {
          // Try getting from SharedPreferences directly
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          if (userId != null) {
            print('🔵 Found user ID from SharedPreferences: $userId');
            user = {
              'id': userId,
              'name': prefs.getString('user_name') ?? 'User',
              'email': prefs.getString('user_email') ?? '',
            };
    }
  }
      }
      
      if (user != null) {
        final userData = user; // Non-nullable reference
        setState(() {
          _currentUserId = userData['id']?.toString();
          _currentUserName = userData['name'] ?? userData['email'] ?? 'User';
        });
        print('🔵 Current user: $_currentUserId ($_currentUserName)');
        Log.i('📞 Current user: $_currentUserId ($_currentUserName)', 'CALL_SCREEN');
      } else {
        print('❌ No user found after trying all methods!');
        Log.e('📞 No user found!', 'CALL_SCREEN');
      }

      // Initialize call service
      print('🔵 Initializing WebRTC call service...');
      Log.i('📞 Initializing WebRTC call service...', 'CALL_SCREEN');
      await _callService.initialize();
      print('🔵 WebRTC call service initialized');
      Log.i('📞 WebRTC call service initialized', 'CALL_SCREEN');

      // Setup call event listeners
        _callService.onCallAccepted = (callId) {
          if (mounted) {
            print('🔔 [ON_CALL_ACCEPTED] Call accepted callback - stopping ringing immediately');
            // Stop ringing IMMEDIATELY when call is accepted (before state change)
            _stopRinging();
            print('🔔 [ON_CALL_ACCEPTED] Ringing stopped');
            setState(() {
              _callState = CallState.active;
              _currentCallId = callId;
            });
            _startCallTimer();
            _startQualityMonitoring(callId);
          }
        };

      _callService.onCallRejected = (callId) {
        if (mounted) {
          setState(() {
            _callState = CallState.rejected;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      };

      _callService.onCallEnded = (callId) {
        print('🔴 [CALL_SCREEN] onCallEnded callback triggered for callId: $callId');
        if (mounted && !_isClosing) {
          _isClosing = true; // Prevent duplicate handling
          setState(() {
            _callState = CallState.ended;
          });
          print('🔴 [CALL_SCREEN] Call state set to ended');
          _stopCallTimer();
          // Stop ringing if still active
          _stopRinging();
          
          // Clear active call ID IMMEDIATELY to prevent new call screens
          try {
            final callIdToClear = callId ?? _currentCallId;
            if (callIdToClear != null) {
              ActiveCallTracker.clearActiveCall(callIdToClear);
              print('🔴 [CALL_SCREEN] Cleared active call ID: $callIdToClear');
            }
          } catch (e) {
            print('⚠️ [CALL_SCREEN] Could not clear active call ID: $e');
          }
          
          // Close call screen after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && Navigator.of(context).canPop()) {
              print('🔴 [CALL_SCREEN] Closing call screen');
              Navigator.of(context).maybePop();
            }
            _isClosing = false;
          });
        } else {
          print('⚠️ [CALL_SCREEN] Already closing or not mounted, skipping duplicate handling');
        }
      };

      _callService.onCallError = (callId, error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Call error: $error')),
          );
          setState(() {
            _callState = CallState.ended;
          });
        }
      };

      // Setup stream listeners
      _callService.onLocalStream = (stream) {
        if (mounted) {
          _localRenderer.srcObject = stream;
          setState(() {});
        }
      };

      _callService.onRemoteStream = (userId, stream) async {
        print('🔵 [CALL_SCREEN] onRemoteStream callback triggered for user: $userId');
        print('🔵 [CALL_SCREEN] Stream ID: ${stream.id}');
        print('🔵 [CALL_SCREEN] Audio tracks: ${stream.getAudioTracks().length}');
        print('🔵 [CALL_SCREEN] Video tracks: ${stream.getVideoTracks().length}');
        
        if (mounted) {
          try {
            // Check if renderer already exists
            if (_remoteRenderers.containsKey(userId)) {
              print('🔵 [CALL_SCREEN] Renderer already exists for $userId, updating stream...');
              _remoteRenderers[userId]!.srcObject = stream;
            } else {
              print('🔵 [CALL_SCREEN] Creating new renderer for $userId...');
              final renderer = RTCVideoRenderer();
              await renderer.initialize();
              renderer.srcObject = stream;
              print('🔵 [CALL_SCREEN] Renderer initialized and stream set');
              _remoteRenderers[userId] = renderer;
            }
            
            setState(() {
              print('🔵 [CALL_SCREEN] setState called - UI should update with remote stream');
            });
            print('🔵 [CALL_SCREEN] ✅ Remote stream setup complete for $userId');
          } catch (e) {
            print('❌ [CALL_SCREEN] Error setting up remote stream renderer: $e');
            Log.e('Error setting up remote stream renderer', 'CALL_SCREEN', e);
          }
        } else {
          print('⚠️ [CALL_SCREEN] Widget not mounted, cannot setup remote stream');
        }
      };

      // Start call if outgoing
      if (widget.direction == CallDirection.outgoing) {
        print('🔵 Direction is outgoing, starting call...');
        final callId = await _startCall();
        if (callId != null) {
          _currentCallId = callId;
        }
        print('🔵 _startCall completed');
      } else {
        print('🔵 Direction is incoming, waiting for call...');
        if (widget.callId != null) {
          _currentCallId = widget.callId;
        }
        }
      print('🔵 _initializeCall completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _initializeCall: $e');
      print('❌ Stack trace: $stackTrace');
      Log.e('Error initializing call', 'CALL_SCREEN', e, stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing call: $e')),
          );
        }
      }
    }

  Future<String?> _startCall() async {
    try {
      print('🔵 _startCall method called');
      if (_currentUserId == null) {
        print('❌ Cannot start call: User not available');
        Log.e('Cannot start call: User not available', 'CALL_SCREEN');
        return null;
      }
      print('🔵 Current user ID: $_currentUserId');

      final participantIds = widget.participantIds ?? [];
    if (participantIds.isEmpty) {
        print('❌ Cannot start call: No participants');
        Log.e('Cannot start call: No participants', 'CALL_SCREEN');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No participants found. Cannot start call.')),
        );
          Navigator.of(context).pop();
      }
      return null;
    }
      print('🔵 Participant IDs: ${participantIds.join(", ")}');

      setState(() {
        _callState = CallState.ringing;
      });
      print('🔵 Call state set to ringing');

      print('🔵 Starting call with chatId: ${widget.chatId}, participants: ${participantIds.length}');
      Log.i('📞 Starting call with chatId: ${widget.chatId}, participants: ${participantIds.length}', 'CALL_SCREEN');
      Log.i('📞 Participant IDs: ${participantIds.join(", ")}', 'CALL_SCREEN');
      print('🔵 Calling _callService.startCall...');
      final callId = await _callService.startCall(
          chatId: widget.chatId,
          chatName: widget.chatName,
          participantIds: participantIds,
        callType: widget.callType,
          isGroupChat: widget.isGroupChat,
        );
      print('🔵 _callService.startCall returned: $callId');
      Log.i('📞 Call start result: callId=$callId', 'CALL_SCREEN');

      if (callId == null) {
        print('❌ Call start returned null - call failed');
          if (mounted) {
          setState(() {
            _callState = CallState.ended;
          });
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start call'),
              duration: Duration(seconds: 3),
            ),
            );
          }
      } else {
        print('✅ Call started successfully with ID: $callId');
        _currentCallId = callId;
        // Call started successfully, wait for acceptance
        setState(() {
          _callState = CallState.ringing;
        });
        return callId;
      }
      return null;
    } catch (e, stackTrace) {
      print('❌ Exception in _startCall: $e');
      print('❌ Stack trace: $stackTrace');
      Log.e('Error starting call', 'CALL_SCREEN', e, stackTrace);
      if (mounted) {
        setState(() {
          _callState = CallState.ended;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting call: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _acceptCall() async {
    try {
      if (widget.callId == null) return;

      print('🔔 [ACCEPT_CALL] Accept button pressed - stopping ringing immediately');
      // Stop ringing IMMEDIATELY when accept button is pressed (before anything else)
      await _stopRinging();
      print('🔔 [ACCEPT_CALL] Vibration stopped immediately on accept');

      setState(() {
        _callState = CallState.active;
      });
      print('🔔 [ACCEPT_CALL] Call state set to active');

      await _callService.acceptCall(widget.callId!);
      print('🔔 [ACCEPT_CALL] Call service acceptCall completed');
      _startCallTimer();
    } catch (e, stackTrace) {
      print('❌ [ACCEPT_CALL] Error accepting call: $e');
      print('❌ [ACCEPT_CALL] Stack trace: $stackTrace');
      Log.e('Error accepting call', 'CALL_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting call: $e')),
        );
      }
    }
  }

  Future<void> _rejectCall() async {
    try {
      // Stop ringing when call is rejected
      await _stopRinging();
      
      if (widget.callId != null) {
        await _callService.rejectCall(widget.callId!);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Log.e('Error rejecting call', 'CALL_SCREEN', e);
    if (mounted) {
      Navigator.of(context).pop();
      }
    }
  }

  Future<void> _endCall() async {
    try {
      await _callService.endCall();
      _stopCallTimer();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Log.e('Error ending call', 'CALL_SCREEN', e);
    if (mounted) {
      Navigator.of(context).pop();
    }
    }
  }

  Future<void> _toggleMute() async {
    await _callService.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _toggleVideo() async {
    await _callService.toggleVideo();
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  Future<void> _switchCamera() async {
    await _callService.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  Future<void> _toggleSpeaker() async {
    await _callService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  /// Start quality monitoring for the call
  void _startQualityMonitoring(String callId) {
    if (callId.isEmpty) return;
    
    // Get the first peer connection (for individual calls) or monitor all (for group calls)
    final peerConnections = _callService.peerConnections;
    if (peerConnections.isNotEmpty) {
      // For now, monitor the first peer connection
      final firstPeerConnection = peerConnections.values.first;
      _qualityService.startMonitoring(callId, firstPeerConnection);
      
      // Set up quality update callback
      _qualityService.onQualityUpdate(callId, (metrics) {
        if (mounted) {
          setState(() {
            _qualityMetrics = metrics;
          });
        }
      });
    }
  }

  /// Stop quality monitoring
  void _stopQualityMonitoring() {
    if (_currentCallId != null && _currentCallId!.isNotEmpty) {
      _qualityService.stopMonitoring(_currentCallId!);
    }
  }
  
  /// Setup call control event listeners
  void _setupCallControlListeners() {
    _callControlsService.onCallHeld((data) {
      if (mounted && data['callId'] == _currentCallId) {
        setState(() {
          _isCallHeld = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call held')),
        );
      }
    });
    
    _callControlsService.onCallResumed((data) {
      if (mounted && data['callId'] == _currentCallId) {
        setState(() {
          _isCallHeld = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call resumed')),
        );
      }
    });
    
    _callControlsService.onParticipantMuted((data) {
      if (mounted && data['callId'] == _currentCallId) {
        final participantId = data['participantId']?.toString();
        final muted = data['muted'] == true;
        if (participantId != null) {
          setState(() {
            _participantMuted[participantId] = muted;
          });
        }
      }
    });
    
    _callControlsService.onScreenShareStarted((data) {
      if (mounted && data['callId'] == _currentCallId) {
        setState(() {
          _isScreenSharing = true;
        });
      }
    });
    
    _callControlsService.onScreenShareStopped((data) {
      if (mounted && data['callId'] == _currentCallId) {
        setState(() {
          _isScreenSharing = false;
        });
      }
    });
  }
  
  /// Toggle screen sharing
  Future<void> _toggleScreenShare() async {
    if (_currentCallId == null) return;
    
    try {
      if (_isScreenSharing) {
        // Stop screen sharing in WebRTC service
        final stopped = await _callService.stopScreenShare();
        if (stopped) {
          // Notify server
          await _callControlsService.stopScreenShare(_currentCallId!);
        }
      } else {
        // Start screen sharing in WebRTC service
        final started = await _callService.startScreenShare();
        if (started) {
          // Notify server
          await _callControlsService.startScreenShare(_currentCallId!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Screen sharing not supported on this device')),
            );
          }
        }
      }
    } catch (e) {
      Log.e('Error toggling screen share', 'CALL_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  /// Toggle call hold
  Future<void> _toggleCallHold() async {
    if (_currentCallId == null) return;
    
    try {
      if (_isCallHeld) {
        await _callControlsService.resumeCall(_currentCallId!);
      } else {
        await _callControlsService.holdCall(_currentCallId!);
      }
    } catch (e) {
      Log.e('Error toggling call hold', 'CALL_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  /// Build call quality indicator widget
  Widget _buildQualityIndicator(bool isMobile) {
    if (_qualityMetrics == null) return const SizedBox.shrink();
    
    final quality = _qualityMetrics!['networkQuality']?.toString() ?? 'unknown';
    final score = _qualityMetrics!['connectionScore'] ?? 0;
    
    Color qualityColor;
    IconData qualityIcon;
    switch (quality.toLowerCase()) {
      case 'excellent':
        qualityColor = Colors.green;
        qualityIcon = Icons.signal_cellular_alt;
        break;
      case 'good':
        qualityColor = Colors.lightGreen;
        qualityIcon = Icons.signal_cellular_alt_2_bar;
        break;
      case 'fair':
        qualityColor = Colors.orange;
        qualityIcon = Icons.signal_cellular_alt_1_bar;
        break;
      case 'poor':
        qualityColor = Colors.red;
        qualityIcon = Icons.signal_cellular_off;
        break;
      default:
        qualityColor = Colors.grey;
        qualityIcon = Icons.signal_cellular_alt;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(qualityIcon, color: qualityColor, size: isMobile ? 16 : 18),
        const SizedBox(width: 4),
        Text(
          '${quality.toUpperCase()} ($score%)',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            color: qualityColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _stopRinging(); // Stop ringing when screen is disposed
    _stopQualityMonitoring(); // Stop quality monitoring
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _remoteRenderers.clear();
    
    // Clear active call ID when screen is disposed
    if (_currentCallId != null) {
      try {
        ActiveCallTracker.clearActiveCall(_currentCallId!);
        print('🔴 [CALL_SCREEN] Cleared active call ID on dispose');
      } catch (e) {
        print('⚠️ [CALL_SCREEN] Could not clear active call ID on dispose: $e');
      }
    }
    
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildCallUI(isMobile, isTablet),
      ),
    );
  }

  Widget _buildCallUI(bool isMobile, bool isTablet) {
    switch (_callState) {
      case CallState.initiating:
      case CallState.ringing:
        return widget.direction == CallDirection.incoming
            ? _buildIncomingCallUI(isMobile, isTablet)
            : _buildOutgoingCallUI(isMobile, isTablet);
      case CallState.active:
        return _buildActiveCallUI(isMobile, isTablet);
      case CallState.ended:
      case CallState.rejected:
        return _buildEndedCallUI(isMobile, isTablet);
      default:
        return _buildOutgoingCallUI(isMobile, isTablet);
    }
  }

  Widget _buildIncomingCallUI(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar/Icon
          CircleAvatar(
            radius: isMobile ? 60 : 80,
            backgroundColor: Colors.blue,
            child: Icon(
              widget.callType == CallType.voice ? Icons.phone : Icons.videocam,
              size: isMobile ? 50 : 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          // Name
          Text(
            widget.chatName,
            style: TextStyle(
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            widget.callType == CallType.voice ? 'Incoming Voice Call' : 'Incoming Video Call',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          // Call controls
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 40 : 80),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reject button
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: _rejectCall,
                  size: isMobile ? 60 : 70,
                ),
                const SizedBox(width: 40),
                // Answer button
                _buildCallButton(
                  icon: widget.callType == CallType.voice
                      ? Icons.phone
                      : Icons.videocam,
                  color: Colors.green,
                  onPressed: _acceptCall,
                  size: isMobile ? 60 : 70,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingCallUI(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar/Icon
          CircleAvatar(
            radius: isMobile ? 60 : 80,
            backgroundColor: Colors.blue,
            child: Icon(
              widget.callType == CallType.voice ? Icons.phone : Icons.videocam,
              size: isMobile ? 50 : 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          // Name
          Text(
            widget.chatName,
            style: TextStyle(
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            widget.callType == CallType.voice ? 'Calling...' : 'Video calling...',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          // Cancel button
          _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _endCall,
            size: isMobile ? 60 : 70,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallUI(bool isMobile, bool isTablet) {
    final remoteStreams = _callService.remoteStreams;
    final isGroupCall = widget.isGroupChat && remoteStreams.length > 1;
    
    // Detect orientation
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Stack(
      children: [
        // Remote video streams - Full screen background
        if (widget.callType == CallType.video)
          Positioned.fill(
            child: _buildVideoStreams(isGroupCall, isMobile, isTablet),
          )
        else
          _buildVoiceCallUI(isMobile, isTablet),
        
        // Local video preview (for video calls) - Positioned based on orientation
        if (widget.callType == CallType.video)
          Positioned(
            top: isLandscape ? 10 : 20,
            right: isLandscape ? 10 : 20,
            child: Container(
              width: isLandscape 
                  ? (isMobile ? 100 : 140)
                  : (isMobile ? 120 : 160),
              height: isLandscape
                  ? (isMobile ? 133 : 186)
                  : (isMobile ? 160 : 213),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isVideoEnabled ? Colors.white : Colors.red,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _localRenderer.srcObject != null && _isVideoEnabled
                    ? RTCVideoView(_localRenderer, mirror: _isFrontCamera)
                    : Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isVideoEnabled ? Icons.person : Icons.videocam_off,
                                color: _isVideoEnabled ? Colors.white70 : Colors.red,
                                size: isMobile ? 40 : 50,
                              ),
                              if (!_isVideoEnabled) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Video Off',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isMobile ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

        // Participant list (for group calls) - Adjust position for landscape
        if (widget.isGroupChat)
          Positioned(
            top: isLandscape ? 10 : 20,
            left: isLandscape ? 10 : 20,
            child: _buildParticipantList(isMobile, isTablet),
          ),

        // Call controls overlay - Semi-transparent, auto-hide in landscape
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildCallControls(isMobile, isTablet, isLandscape),
        ),
      ],
    );
  }

  Widget _buildVideoStreams(bool isGroupCall, bool isMobile, bool isTablet) {
    final remoteStreams = _callService.remoteStreams;
    
    if (remoteStreams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isMobile ? 60 : 80,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.person,
                size: isMobile ? 50 : 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.chatName,
              style: TextStyle(
                fontSize: isMobile ? 24 : 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (isGroupCall) {
      // Grid layout for group calls
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: remoteStreams.length,
        itemBuilder: (context, index) {
          final userId = remoteStreams.keys.elementAt(index);
          final renderer = _remoteRenderers[userId];
          if (renderer == null) {
            return Container(
              color: Colors.grey[900],
              child: const Center(child: Icon(Icons.person, color: Colors.white70)),
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(renderer),
            ),
          );
        },
      );
    } else {
      // Full screen for individual calls
      final userId = remoteStreams.keys.first;
      final renderer = _remoteRenderers[userId];
      if (renderer == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: isMobile ? 60 : 80,
                backgroundColor: Colors.blue,
                child: Icon(
                  Icons.person,
                  size: isMobile ? 50 : 70,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.chatName,
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
      // Full screen video with proper aspect ratio - ensures video is always visible
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 640,
            height: 480,
            child: RTCVideoView(renderer),
          ),
        ),
      );
    }
  }

  Widget _buildVoiceCallUI(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: isMobile ? 60 : 80,
            backgroundColor: Colors.blue,
            child: Icon(
              Icons.person,
              size: isMobile ? 50 : 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            widget.chatName,
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(_callDuration),
            style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls(bool isMobile, bool isTablet, [bool isLandscape = false]) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isLandscape ? 10 : 20,
        horizontal: isLandscape ? 10 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isLandscape ? 0.5 : 0.7),
        borderRadius: isLandscape 
            ? BorderRadius.zero
            : const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Call duration
          Text(
            _formatDuration(_callDuration),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // Call quality indicator
          if (_qualityMetrics != null) ...[
            const SizedBox(height: 8),
            _buildQualityIndicator(isMobile),
          ],
          const SizedBox(height: 20),
          // Control buttons - Primary row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: isMobile ? 8 : 12,
            runSpacing: isMobile ? 8 : 12,
            children: [
              // Mute button
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.red : Colors.white70,
                onPressed: _toggleMute,
                size: isMobile ? 50 : 60,
              ),
              // Speaker button
              _buildControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                color: _isSpeakerOn ? Colors.green : Colors.white70,
                onPressed: _toggleSpeaker,
                size: isMobile ? 50 : 60,
              ),
              // Video toggle (only for video calls)
              if (widget.callType == CallType.video)
                _buildControlButton(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  color: _isVideoEnabled ? Colors.white70 : Colors.red,
                  onPressed: _toggleVideo,
                  size: isMobile ? 50 : 60,
                ),
              // Switch camera (only for video calls)
              if (widget.callType == CallType.video)
                _buildControlButton(
                  icon: Icons.switch_camera,
                  color: Colors.white70,
                  onPressed: _switchCamera,
                  size: isMobile ? 50 : 60,
                ),
              // Screen share (only for video calls)
              if (widget.callType == CallType.video)
                _buildControlButton(
                  icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: _isScreenSharing ? Colors.orange : Colors.white70,
                  onPressed: _toggleScreenShare,
                  size: isMobile ? 50 : 60,
                ),
              // Hold/Resume button
              _buildControlButton(
                icon: _isCallHeld ? Icons.play_arrow : Icons.pause,
                color: _isCallHeld ? Colors.orange : Colors.white70,
                onPressed: _toggleCallHold,
                size: isMobile ? 50 : 60,
              ),
              // End call button
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.red,
                onPressed: _endCall,
                size: isMobile ? 60 : 70,
              ),
            ],
          ),
          // Additional controls for group calls (if host)
          if (widget.isGroupChat && _isCallHost) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Group Controls',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isMobile ? 8 : 12,
              children: [
                // Mute all button
                _buildControlButton(
                  icon: Icons.volume_off,
                  color: Colors.white70,
                  onPressed: () async {
                    if (_currentCallId != null) {
                      await _callControlsService.muteAllParticipants(
                        callId: _currentCallId!,
                        muted: true,
                      );
                    }
                  },
                  size: isMobile ? 45 : 55,
                ),
                // Unmute all button
                _buildControlButton(
                  icon: Icons.volume_up,
                  color: Colors.white70,
                  onPressed: () async {
                    if (_currentCallId != null) {
                      await _callControlsService.muteAllParticipants(
                        callId: _currentCallId!,
                        muted: false,
                      );
                    }
                  },
                  size: isMobile ? 45 : 55,
                ),
              ],
            ),
          ],
          // Call actions (forward/transfer) - Secondary row
          if (!widget.isGroupChat) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isMobile ? 8 : 12,
              children: [
                // Forward button
                _buildControlButton(
                  icon: Icons.call_made,
                  color: Colors.white70,
                  onPressed: _showForwardDialog,
                  size: isMobile ? 45 : 55,
                ),
                // Transfer button
                _buildControlButton(
                  icon: Icons.swap_calls,
                  color: Colors.white70,
                  onPressed: _showTransferDialog,
                  size: isMobile ? 45 : 55,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEndedCallUI(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.call_end,
          size: 80,
          color: Colors.white70,
        ),
        const SizedBox(height: 20),
          Text(
            _callState == CallState.rejected ? 'Call Rejected' : 'Call Ended',
          style: TextStyle(
              fontSize: isMobile ? 24 : 32,
            color: Colors.white70,
          ),
            textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
            onPressed: () {
              print('🔵 Close button pressed');
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close', style: TextStyle(fontSize: 18)),
        ),
      ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }
  
  /// Build participant list widget for group calls
  Widget _buildParticipantList(bool isMobile, bool isTablet) {
    if (!widget.isGroupChat || widget.participantIds == null || widget.participantIds!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Participants (${widget.participantIds!.length + 1})',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_isCallHost)
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                  onPressed: () => _showParticipantControls(),
                  tooltip: 'Participant controls',
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Current user
          _buildParticipantItem(
            _currentUserName ?? 'You',
            _currentUserId ?? '',
            isMuted: _isMuted,
            isMobile: isMobile,
          ),
          // Other participants
          ...widget.participantIds!.map((participantId) {
            final isMuted = _participantMuted[participantId] ?? false;
            final shortId = participantId.length > 8 ? participantId.substring(0, 8) : participantId;
            return _buildParticipantItem(
              'Participant $shortId',
              participantId,
              isMuted: isMuted,
              isMobile: isMobile,
              canMute: _isCallHost,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(
    String name,
    String participantId, {
    required bool isMuted,
    required bool isMobile,
    bool canMute = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: Row(
        children: [
          Icon(
            isMuted ? Icons.mic_off : Icons.mic,
            size: isMobile ? 16 : 18,
            color: isMuted ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: isMobile ? 13 : 15,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canMute && participantId != _currentUserId)
            IconButton(
              icon: Icon(
                isMuted ? Icons.volume_up : Icons.volume_off,
                size: isMobile ? 18 : 20,
                color: Colors.white70,
              ),
              onPressed: () => _muteParticipant(participantId, !isMuted),
              tooltip: isMuted ? 'Unmute' : 'Mute',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isMobile ? 32 : 36,
                minHeight: isMobile ? 32 : 36,
              ),
            ),
        ],
      ),
    );
  }

  void _showParticipantControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Participant Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.participantIds != null)
              ...widget.participantIds!.map((participantId) {
                final isMuted = _participantMuted[participantId] ?? false;
                final shortId = participantId.length > 8 ? participantId.substring(0, 8) : participantId;
                return ListTile(
                  leading: Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    color: isMuted ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    'Participant $shortId',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Switch(
                    value: !isMuted,
                    onChanged: (value) => _muteParticipant(participantId, !value),
                  ),
                  onTap: () => _muteParticipant(participantId, !isMuted),
                );
              }),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Mute a participant (for group calls)
  Future<void> _muteParticipant(String participantId, bool muted) async {
    if (_currentCallId == null || !_isCallHost) return;
    
    try {
      final success = await _callControlsService.muteParticipant(
        callId: _currentCallId!,
        participantId: participantId,
        muted: muted,
      );
      if (success && mounted) {
        setState(() {
          _participantMuted[participantId] = muted;
        });
      }
    } catch (e) {
      Log.e('Error muting participant', 'CALL_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  /// Show forward call dialog
  Future<void> _showForwardDialog() async {
    if (!mounted) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch user details for all participants
      final availableUsers = <Map<String, dynamic>>[];
      
      if (widget.participantIds != null && widget.participantIds!.isNotEmpty) {
        for (final userId in widget.participantIds!) {
          try {
            // Fetch user details from API
            final userDetails = await _fetchUserDetails(userId);
            if (userDetails != null) {
              availableUsers.add({
                'id': userId,
                '_id': userId,
                'name': userDetails['name'] ?? userDetails['displayName'] ?? userDetails['username'] ?? 'Unknown',
                'email': userDetails['email'] ?? '',
              });
            } else {
              // Fallback to ID if user not found
              availableUsers.add({
                'id': userId,
                '_id': userId,
                'name': 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
                'email': '',
              });
            }
          } catch (e) {
            print('⚠️ Error fetching user $userId: $e');
            // Add with fallback name
            availableUsers.add({
              'id': userId,
              '_id': userId,
              'name': 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
              'email': '',
            });
          }
        }
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      if (availableUsers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No users available to forward to')),
          );
        }
        return;
      }
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CallForwardDialog(
          availableUsers: availableUsers,
          onForward: (userId) async {
            if (_currentCallId != null) {
              final success = await _callControlsService.forwardCall(
                callId: _currentCallId!,
                forwardToUserId: userId,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Call forwarded')),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: ${e.toString()}')),
        );
      }
    }
  }
  
  /// Fetch user details from API
  Future<Map<String, dynamic>?> _fetchUserDetails(String userId) async {
    try {
      final token = await DatabaseConfig.getStoredAuthToken();
      if (token.isEmpty) return null;
      
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          if (!kIsWeb) 'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'id': data['id'] ?? data['_id'] ?? userId,
          'name': data['name'] ?? data['displayName'] ?? data['username'] ?? 'Unknown',
          'email': data['email'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }
  
  /// Show transfer call dialog
  Future<void> _showTransferDialog() async {
    if (!mounted) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch user details for all participants
      final availableUsers = <Map<String, dynamic>>[];
      
      if (widget.participantIds != null && widget.participantIds!.isNotEmpty) {
        for (final userId in widget.participantIds!) {
          try {
            // Fetch user details from API
            final userDetails = await _fetchUserDetails(userId);
            if (userDetails != null) {
              availableUsers.add({
                'id': userId,
                '_id': userId,
                'name': userDetails['name'] ?? userDetails['displayName'] ?? userDetails['username'] ?? 'Unknown',
                'email': userDetails['email'] ?? '',
              });
            } else {
              // Fallback to ID if user not found
              availableUsers.add({
                'id': userId,
                '_id': userId,
                'name': 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
                'email': '',
              });
            }
          } catch (e) {
            print('⚠️ Error fetching user $userId: $e');
            // Add with fallback name
            availableUsers.add({
              'id': userId,
              '_id': userId,
              'name': 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
              'email': '',
            });
          }
        }
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      if (availableUsers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No users available to transfer to')),
          );
        }
        return;
      }
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CallTransferDialog(
          availableUsers: availableUsers,
        onTransfer: (userId, transferType) async {
          if (_currentCallId != null) {
            final success = await _callControlsService.transferCall(
              callId: _currentCallId!,
              transferToUserId: userId,
              transferType: transferType,
            );
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call transferred')),
              );
              // End current call after transfer
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  _endCall();
                }
              });
            }
          }
        },
      ),
    );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: ${e.toString()}')),
        );
      }
    }
  }
}

