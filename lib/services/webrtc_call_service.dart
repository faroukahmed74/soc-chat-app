import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/database_config.dart';
import '../services/logger_service.dart';
import '../services/realtime_service.dart';
import '../services/local_auth_service.dart';
import '../services/call_history_service.dart';
import '../services/call_permission_service.dart';
import '../main.dart'; // For navigatorKey
import 'call_types.dart';

/// WebRTC Call Service
/// Handles WebRTC signaling, peer connections, and call management
/// Supports both individual and group calls
class WebRTCCallService {
  static final WebRTCCallService _instance = WebRTCCallService._internal();
  factory WebRTCCallService() => _instance;
  WebRTCCallService._internal();

  RealtimeService _realtime = RealtimeService.instance;
  String? _currentUserId;
  String? _currentCallId;
  CallType? _currentCallType;
  bool _isInCall = false;

  // WebRTC peer connections (for group calls, we'll have multiple)
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  MediaStream? _screenShareStream; // Screen sharing stream
  final Map<String, MediaStream> _remoteStreams = {};
  bool _isSpeakerOn = false; // Track speaker state
  bool _isScreenSharing = false; // Track screen sharing state
  
  // Store pending offers that arrive before call acceptance
  final Map<String, Map<String, dynamic>> _pendingOffers = {};
  
  // Reconnection tracking
  final Map<String, Timer?> _reconnectionTimers = {};
  final Map<String, int> _reconnectionAttempts = {};
  static const int _maxReconnectionAttempts = 3;
  static const Duration _reconnectionDelay = Duration(seconds: 2);

  // Call history tracking
  DateTime? _callStartTime;
  DateTime? _callAnswerTime;
  DateTime? _callEndTime;
  String? _currentChatId;
  String? _currentChatName;
  List<String>? _currentParticipantIds;
  bool _currentIsGroupChat = false;
  late CallHistoryService _callHistory;

  // STUN/TURN servers configuration
  // Using Google's public STUN servers for NAT traversal
  // TURN servers for strict NAT/firewall scenarios (self-hosted coturn)
  List<Map<String, dynamic>> _iceServers = [];
  
  /// Initialize ICE servers (STUN + TURN)
  void _initializeIceServers() {
    _iceServers = [
      // STUN servers (always included)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ];
    
    // Add TURN servers if configured
    // TURN configuration can be set via environment or hardcoded
    // Format: TURN_SERVER_IP, TURN_SERVER_PORT, TURN_USERNAME, TURN_PASSWORD
    // For now, we'll use a configuration that can be set at runtime
    final turnServerIp = const String.fromEnvironment('TURN_SERVER_IP', defaultValue: '');
    final turnServerPort = const String.fromEnvironment('TURN_SERVER_PORT', defaultValue: '3478');
    final turnUsername = const String.fromEnvironment('TURN_USERNAME', defaultValue: '');
    final turnPassword = const String.fromEnvironment('TURN_PASSWORD', defaultValue: '');
    
    if (turnServerIp.isNotEmpty && turnUsername.isNotEmpty && turnPassword.isNotEmpty) {
      // Add TURN servers (UDP and TCP)
      _iceServers.addAll([
        {
          'urls': 'turn:$turnServerIp:$turnServerPort',
          'username': turnUsername,
          'credential': turnPassword,
        },
        {
          'urls': 'turn:$turnServerIp:$turnServerPort?transport=tcp',
          'username': turnUsername,
          'credential': turnPassword,
        },
      ]);
      Log.i('TURN servers configured: $turnServerIp:$turnServerPort', 'WEBRTC_CALL_SERVICE');
    } else {
      // Default TURN configuration (can be updated via setTurnServerConfig)
      // These will be empty initially and can be set at runtime
      Log.w('TURN servers not configured. Use setTurnServerConfig() to add them.', 'WEBRTC_CALL_SERVICE');
    }
  }
  
  /// Set TURN server configuration at runtime
  /// For web: use local network IP
  /// For mobile: use ngrok URL or local IP if on same network
  Future<void> setTurnServerConfig({
    String? serverIp,  // Local network IP (for web)
    String? ngrokUrl,  // Ngrok URL (for mobile)
    String port = '3478',
    String? username,
    String? password,
  }) async {
    // Remove existing TURN servers
    _iceServers.removeWhere((server) => 
      server['urls']?.toString().startsWith('turn:') == true
    );
    
    if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
      // For web: use local network IP (primary) + ngrok TCP tunnel (for cross-platform calls with mobile)
      if (kIsWeb) {
        // Web clients use local IP TURN server via proxy (primary for web-to-web calls)
        if (serverIp != null) {
          _iceServers.addAll([
            {
              'urls': 'turn:$serverIp:$port',
              'username': username,
              'credential': password,
            },
            {
              'urls': 'turn:$serverIp:$port?transport=tcp',
              'username': username,
              'credential': password,
            },
          ]);
          Log.i('TURN servers configured for Web (local IP via proxy): $serverIp:$port', 'WEBRTC_CALL_SERVICE');
        } else {
          Log.w('⚠️ Web TURN server not configured - serverIp is null', 'WEBRTC_CALL_SERVICE');
        }
        
        // Also fetch ngrok TCP tunnel for cross-platform calls (web-to-mobile)
        if (ngrokUrl != null && ngrokUrl.isNotEmpty) {
          await _configureMobileTurnWithNgrok(ngrokUrl, username!, password!);
          Log.i('Web TURN servers configured with ngrok (for cross-platform calls with mobile)', 'WEBRTC_CALL_SERVICE');
        }
      }
      // For mobile: ALWAYS use ngrok TCP tunnel first (required for cross-network calls)
      // Only add local IP as fallback if ngrok is not available
      else if (!kIsWeb) {
        // For mobile devices, prioritize ngrok TURN server for cross-network calls
        // Fetch ngrok TURN servers first (this will replace any existing TURN servers)
        if (ngrokUrl != null && ngrokUrl.isNotEmpty) {
          await _configureMobileTurnWithNgrok(ngrokUrl, username!, password!);
          
          // Only add local IP as fallback if ngrok TURN servers were not found
          // Check if we have ngrok TURN servers
          final hasNgrokTurn = _iceServers.any((server) => 
            server['urls']?.toString().contains('ngrok') == true
          );
          
          if (!hasNgrokTurn && serverIp != null) {
            // No ngrok TURN servers found, add local IP as fallback
            _iceServers.addAll([
              {
                'urls': 'turn:$serverIp:$port',
                'username': username,
                'credential': password,
              },
              {
                'urls': 'turn:$serverIp:$port?transport=tcp',
                'username': username,
                'credential': password,
              },
            ]);
            Log.w('TURN servers configured for Mobile (local IP fallback - ngrok not available): $serverIp:$port', 'WEBRTC_CALL_SERVICE');
          } else if (hasNgrokTurn) {
            Log.i('✅ Mobile TURN servers configured with ngrok (local IP not needed)', 'WEBRTC_CALL_SERVICE');
          }
        } else {
          // No ngrok URL provided, use local IP only
          if (serverIp != null) {
            _iceServers.addAll([
              {
                'urls': 'turn:$serverIp:$port',
                'username': username,
                'credential': password,
              },
              {
                'urls': 'turn:$serverIp:$port?transport=tcp',
                'username': username,
                'credential': password,
              },
            ]);
            Log.w('TURN servers configured for Mobile (local IP only - ngrok URL not provided): $serverIp:$port', 'WEBRTC_CALL_SERVICE');
          }
        }
      }
    }
  }

  /// Configure TURN server using ngrok TCP tunnel (for both web and mobile)
  /// Fetches TURN configuration from server API which includes ngrok TCP tunnel + local IP fallback
  Future<void> _configureMobileTurnWithNgrok(String ngrokUrl, String username, String password) async {
    try {
      // Fetch TURN configuration from server API (server can access ngrok API)
      final serverUrl = ngrokUrl.replaceAll('/api', ''); // Remove /api if present
      final turnConfigUrl = '$serverUrl/api/webrtc/turn-config';
      
      print('🔵 [TURN_CONFIG] Fetching TURN configuration from server: $turnConfigUrl');
      final response = await http.get(
        Uri.parse(turnConfigUrl),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['turnServers'] != null) {
          final turnServers = List<Map<String, dynamic>>.from(data['turnServers']);
          
          // Remove any existing TURN servers (keep STUN servers)
          _iceServers.removeWhere((server) => 
            server['urls']?.toString().startsWith('turn:') == true
          );
          
          // Add TURN servers from server response (ngrok first, then local IP fallback)
          // The server returns them in priority order: ngrok TCP tunnel first, then local IP
          // IMPORTANT: Add ngrok TURN servers FIRST so they are tried before local IP
          // This ensures devices on mobile data use ngrok TURN server
          _iceServers.addAll(turnServers);
          
          print('🔵 [TURN_CONFIG] ✅ TURN servers added in priority order:');
          for (int i = 0; i < turnServers.length; i++) {
            final server = turnServers[i];
            final isNgrok = server['urls']?.toString().contains('ngrok') ?? false;
            print('   ${i + 1}. ${server['urls']} ${isNgrok ? "(NGROK - for mobile data)" : "(Local IP - fallback)"}');
          }
          
          final tcpTunnelUrl = data['tcpTunnelUrl'];
          if (tcpTunnelUrl != null) {
            print('✅ [TURN_CONFIG] TURN servers configured with ngrok TCP tunnel: $tcpTunnelUrl');
            Log.i('TURN servers configured for Mobile (ngrok TCP): $tcpTunnelUrl', 'WEBRTC_CALL_SERVICE');
          } else {
            print('⚠️ [TURN_CONFIG] TURN servers configured with local IP only (ngrok TCP tunnel not available)');
            Log.w('TURN servers configured with local IP only (ngrok TCP tunnel not available)', 'WEBRTC_CALL_SERVICE');
          }
          
          // Log final ICE server configuration
          print('🔵 [TURN_CONFIG] Final ICE servers (in priority order):');
          for (int i = 0; i < _iceServers.length; i++) {
            final server = _iceServers[i];
            final urls = server['urls']?.toString() ?? 'unknown';
            final isTurn = urls.startsWith('turn:');
            final isNgrok = urls.contains('ngrok');
            final isStun = urls.startsWith('stun:');
            String type = isStun ? 'STUN' : (isNgrok ? 'TURN (NGROK)' : (isTurn ? 'TURN (Local)' : 'Unknown'));
            print('   ${i + 1}. $urls - $type');
          }
          return;
        }
      }
      
      // Fallback: keep existing local IP TURN servers (already added in setTurnServerConfig)
      print('⚠️ [TURN_CONFIG] Could not get TURN config from server, keeping local IP fallback');
      Log.w('TURN servers configured with local IP fallback (server API failed)', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      print('❌ [TURN_CONFIG] Error fetching TURN configuration: $e');
      Log.e('Error getting TURN configuration from server', 'WEBRTC_CALL_SERVICE', e);
      
      // Fallback: keep existing local IP TURN servers (already added in setTurnServerConfig)
      print('⚠️ [TURN_CONFIG] Keeping local IP TURN servers as fallback');
      Log.w('TURN servers configured with local IP fallback (error occurred)', 'WEBRTC_CALL_SERVICE');
    }
  }


  // Callbacks
  Function(String callId, CallType callType, CallDirection direction)? onIncomingCall;
  Function(String callId)? onCallAccepted;
  Function(String callId)? onCallRejected;
  Function(String callId)? onCallEnded;
  Function(String callId, String error)? onCallError;
  Function(String userId, MediaStream stream)? onRemoteStream;
  Function(MediaStream stream)? onLocalStream;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Initialize ICE servers (STUN + TURN)
      _initializeIceServers();
      
      // Initialize call history service
      _callHistory = CallHistoryService();
      
      // Log platform and server configuration
      final platform = kIsWeb ? 'Web' : 'Mobile';
      final serverUrl = DatabaseConfig.physicalServerUrl;
      Log.i('Initializing WebRTC Call Service', 'WEBRTC_CALL_SERVICE');
      Log.i('Platform: $platform', 'WEBRTC_CALL_SERVICE');
      Log.i('Server URL: $serverUrl', 'WEBRTC_CALL_SERVICE');
      Log.i('ICE Servers: ${_iceServers.map((s) => s['urls']).join(", ")}', 'WEBRTC_CALL_SERVICE');
      
      await _realtime.connect();
      
      // Get current user ID - try multiple methods
      print('🔵 WebRTC: Getting current user ID...');
      final prefs = await SharedPreferences.getInstance();
      
      // Method 1: Try current_user (JSON format)
      var userStr = prefs.getString('current_user');
      if (userStr != null) {
        try {
          final user = json.decode(userStr);
          _currentUserId = user['id']?.toString();
          if (_currentUserId != null) {
            print('🔵 WebRTC: Found user ID from current_user: $_currentUserId');
            Log.i('Current User ID: $_currentUserId', 'WEBRTC_CALL_SERVICE');
          }
        } catch (e) {
          print('🔵 WebRTC: Error parsing current_user: $e');
        }
      }
      
      // Method 2: Try user_id (direct string)
      if (_currentUserId == null) {
        final userId = prefs.getString('user_id');
        if (userId != null) {
          _currentUserId = userId;
          print('🔵 WebRTC: Found user ID from user_id: $_currentUserId');
          Log.i('Current User ID: $_currentUserId', 'WEBRTC_CALL_SERVICE');
        }
      }
      
      // Method 3: Try LocalAuthService
      if (_currentUserId == null) {
        try {
          final userId = await LocalAuthService.getCurrentUserIdAsync();
          if (userId != null) {
            _currentUserId = userId;
            print('🔵 WebRTC: Found user ID from LocalAuthService: $_currentUserId');
            Log.i('Current User ID: $_currentUserId', 'WEBRTC_CALL_SERVICE');
          }
        } catch (e) {
          print('🔵 WebRTC: Error getting user ID from LocalAuthService: $e');
        }
      }
      
      if (_currentUserId == null) {
        print('❌ WebRTC: No user ID found after trying all methods');
        Log.w('No user ID found in WebRTC service', 'WEBRTC_CALL_SERVICE');
      }

      // Listen for call events
      _setupCallListeners();
      
      Log.i('WebRTC Call Service initialized successfully', 'WEBRTC_CALL_SERVICE');
      Log.i('Cross-platform calls supported: Mobile (ngrok) ↔ Web (proxy)', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error initializing WebRTC Call Service', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Setup Socket.IO listeners for call signaling
  void _setupCallListeners() {
    // Wait for connection if not connected yet
    if (!_realtime.isConnected) {
      Log.w('Realtime not connected, will setup listeners when connected', 'WEBRTC_CALL_SERVICE');
      // Try to connect and setup listeners
      _realtime.connect().then((_) {
        _setupCallListeners();
      }).catchError((e) {
        Log.e('Failed to connect realtime for call listeners', 'WEBRTC_CALL_SERVICE', e);
      });
      return;
    }

    // Listen for incoming call invitations using the proper handler method
    _realtime.onCallInvitation((data) {
      try {
        print('📞 [CLIENT] Received call_invitation event');
        print('   Data type: ${data.runtimeType}');
        print('   Data: $data');
        Log.i('📞 [CLIENT] Received call_invitation event: $data', 'WEBRTC_CALL_SERVICE');
        
        if (data is! Map) {
          print('❌ [CLIENT] Call invitation data is not a Map');
          Log.w('Call invitation data is not a Map', 'WEBRTC_CALL_SERVICE');
          return;
        }
        
        final callData = Map<String, dynamic>.from(data);
        
        final callId = callData['callId']?.toString();
        final callerId = callData['callerId']?.toString();
        final callTypeStr = callData['callType']?.toString() ?? 'video';
        // Handle both 'voice' and 'audio' from server (normalize to CallType.voice)
        final callType = (callTypeStr == 'voice' || callTypeStr == 'audio') ? CallType.voice : CallType.video;
        final chatId = callData['chatId']?.toString() ?? '';
        final chatName = callData['chatName']?.toString() ?? 'Unknown';
        final participantIds = (callData['participantIds'] as List<dynamic>?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        final isGroupChat = callData['isGroupChat'] == true;

        print('📞 [CLIENT] Parsed call data:');
        print('   callId: $callId');
        print('   callerId: $callerId');
        print('   currentUserId: $_currentUserId');
        print('   callType: $callTypeStr -> $callType');
        print('   chatId: $chatId');
        print('   chatName: $chatName');
        print('   participants: ${participantIds.length}');
        
        Log.i('📞 [CLIENT] Parsed: callId=$callId, callerId=$callerId, chatId=$chatId', 'WEBRTC_CALL_SERVICE');

        if (callId == null || callerId == null) {
          print('❌ [CLIENT] Missing callId or callerId');
          Log.w('Missing callId or callerId in call invitation', 'WEBRTC_CALL_SERVICE');
          return;
        }
        
        if (callerId == _currentUserId) {
          print('ℹ️ [CLIENT] Ignoring own call');
          Log.i('Ignoring own call invitation', 'WEBRTC_CALL_SERVICE');
          return; // Ignore own calls
        }

        print('✅ [CLIENT] Processing incoming call: $callId');
        
        // Check if this call is already being handled (prevent duplicate processing)
        if (_currentCallId == callId && _isInCall) {
          print('⚠️ [CLIENT] Call $callId already being processed, ignoring duplicate invitation');
          Log.w('Call already being processed, ignoring duplicate invitation', 'WEBRTC_CALL_SERVICE');
          return;
        }
        
        _currentCallId = callId;
        _currentCallType = callType;

        // Track incoming call for history
        trackIncomingCall(callId, chatId, chatName, participantIds, isGroupChat);
        
        // NOTE: onIncomingCall callback is NOT used for navigation
        // Navigation is handled by the global listener in main.dart
        // This callback is only for WebRTC service internal state management
        print('📞 [CLIENT] Call invitation processed (navigation handled by global listener)');
        Log.i('✅ [CLIENT] Incoming call processed: $callId', 'WEBRTC_CALL_SERVICE');
      } catch (e, stackTrace) {
        print('❌ [CLIENT] Error handling call invitation: $e');
        print('   Stack trace: $stackTrace');
        Log.e('Error handling call invitation', 'WEBRTC_CALL_SERVICE', e);
        Log.e('Stack trace', 'WEBRTC_CALL_SERVICE', stackTrace);
      }
    });

    // Listen for call acceptance
    _realtime.on('call_accepted', (data) {
      try {
        print('🔵 [CALL_ACCEPTED] Received call_accepted event: $data');
        if (data is! Map) {
          print('❌ [CALL_ACCEPTED] Data is not a Map');
          return;
        }
        final callData = Map<String, dynamic>.from(data);
        final callId = callData['callId']?.toString();
        // Server sends 'acceptedBy', but we also check 'userId' for compatibility
        final acceptedBy = callData['acceptedBy']?.toString() ?? callData['userId']?.toString();
        
        print('🔵 [CALL_ACCEPTED] callId: $callId, acceptedBy: $acceptedBy, currentCallId: $_currentCallId');
        
        if (callId == null || acceptedBy == null) {
          print('❌ [CALL_ACCEPTED] Missing callId or acceptedBy');
          return;
        }
        
        if (callId == _currentCallId) {
          print('✅ [CALL_ACCEPTED] Call accepted: $callId by $acceptedBy');
          _isInCall = true;
          markCallAnswered(); // Mark as answered for history
          onCallAccepted?.call(callId);
          Log.i('Call accepted: $callId by $acceptedBy', 'WEBRTC_CALL_SERVICE');
        } else {
          print('⚠️ [CALL_ACCEPTED] Call ID mismatch: received=$callId, current=$_currentCallId');
        }
      } catch (e, stackTrace) {
        print('❌ [CALL_ACCEPTED] Error handling call acceptance: $e');
        print('❌ [CALL_ACCEPTED] Stack trace: $stackTrace');
        Log.e('Error handling call acceptance', 'WEBRTC_CALL_SERVICE', e);
      }
    });

    // Listen for call rejection
    _realtime.on('call_rejected', (data) {
      try {
        if (data is! Map) return;
        final callData = Map<String, dynamic>.from(data);
        final callId = callData['callId']?.toString();
        
        if (callId == null) return;
        if (callId == _currentCallId) {
          _resetCallState();
          onCallRejected?.call(callId);
          Log.i('Call rejected: $callId', 'WEBRTC_CALL_SERVICE');
        }
      } catch (e) {
        Log.e('Error handling call rejection', 'WEBRTC_CALL_SERVICE', e);
      }
    });

    // Listen for call end
    _realtime.on('call_ended', (data) {
      try {
        print('🔴 [CALL_ENDED] Received call_ended event: $data');
        if (data is! Map) {
          print('❌ [CALL_ENDED] Data is not a Map');
          return;
        }
        final callData = Map<String, dynamic>.from(data);
        final callId = callData['callId']?.toString();
        final endedBy = callData['endedBy']?.toString();
        
        print('🔴 [CALL_ENDED] callId: $callId, endedBy: $endedBy, currentCallId: $_currentCallId');
        
        if (callId == null) {
          print('❌ [CALL_ENDED] Missing callId');
          return;
        }
        
        if (callId == _currentCallId) {
          print('✅ [CALL_ENDED] Call ended: $callId by $endedBy');
          _resetCallState();
          onCallEnded?.call(callId);
          Log.i('Call ended: $callId by $endedBy', 'WEBRTC_CALL_SERVICE');
        } else {
          print('⚠️ [CALL_ENDED] Call ID mismatch: received=$callId, current=$_currentCallId');
        }
      } catch (e, stackTrace) {
        print('❌ [CALL_ENDED] Error handling call end: $e');
        print('❌ [CALL_ENDED] Stack trace: $stackTrace');
        Log.e('Error handling call end', 'WEBRTC_CALL_SERVICE', e);
      }
    });

    // Listen for WebRTC signaling (SDP offers/answers, ICE candidates)
    _realtime.on('webrtc_offer', (data) {
      _handleWebRTCSignal('offer', data);
    });

    _realtime.on('webrtc_answer', (data) {
      _handleWebRTCSignal('answer', data);
    });

    _realtime.on('webrtc_ice_candidate', (data) {
      _handleWebRTCSignal('ice-candidate', data);
    });
  }

  /// Handle WebRTC signaling messages
  Future<void> _handleWebRTCSignal(String type, dynamic data) async {
    try {
      if (data is! Map) {
        print('❌ Signal data is not a Map: ${data.runtimeType}');
        return;
      }
      final signalData = Map<String, dynamic>.from(data);
      final callId = signalData['callId']?.toString();
      // Support both 'userId' and 'fromUserId' for compatibility
      final userId = signalData['userId']?.toString() ?? signalData['fromUserId']?.toString();
      
      print('🔵 [SIGNAL] Handling WebRTC signal: type=$type, callId=$callId, userId=$userId, currentCallId=$_currentCallId');
      
      // For incoming calls, we might receive offers before acceptCall() is called
      // So we need to allow signals even if _currentCallId is not set yet
      if (callId != null && _currentCallId != null && callId != _currentCallId) {
        print('❌ [SIGNAL] Call ID mismatch: received=$callId, current=$_currentCallId');
        return;
      }
      
      // If we don't have a current call ID but we're receiving an offer, set it
      if (type == 'offer' && _currentCallId == null && callId != null) {
        print('🔵 [SIGNAL] Setting current call ID from offer: $callId');
        _currentCallId = callId;
      }
      
      if (userId == null) {
        print('❌ [SIGNAL] User ID is null in signal');
        return;
      }
      if (userId == _currentUserId) {
        print('🔵 [SIGNAL] Ignoring own signal from $userId');
        return; // Ignore own signals
      }
      
      RTCPeerConnection? peerConnection = _peerConnections[userId];

      switch (type) {
        case 'offer':
          // Handle offer signal - server sends {callId, userId, offer: {sdp, type}}
          final offer = signalData['offer'];
          
          if (offer != null && offer is Map) {
            print('🔵 [OFFER] Received offer from $userId for call $callId');
            
            // If peer connection doesn't exist, create it (for incoming calls)
            if (peerConnection == null) {
              print('🔵 [OFFER] Creating peer connection for incoming call from $userId');
              peerConnection = await _createPeerConnection(userId);
              _peerConnections[userId] = peerConnection;
            }
            
            // Detect call type from offer if not set
            if (_currentCallType == null && offer['sdp'] != null) {
              final sdpStr = offer['sdp'].toString();
              final hasVideo = sdpStr.contains('m=video');
              _currentCallType = hasVideo ? CallType.video : CallType.voice;
              print('🔵 [OFFER] Call type not set, detecting from SDP: video=$hasVideo, callType=$_currentCallType');
            }
            
            // CRITICAL: Only get local stream if call is already accepted (_isInCall = true)
            // For incoming calls, wait until acceptCall() is called to avoid opening camera/mic before acceptance
            if (!_isInCall) {
              print('🔵 [OFFER] ⚠️ Call not yet accepted - storing offer for later processing');
              print('🔵 [OFFER] Will get local stream, set remote description, and create answer when acceptCall() is called');
              
              // Store the offer to process it in acceptCall()
              _pendingOffers[userId] = {
                'offer': offer,
                'callId': callId,
              };
              print('🔵 [OFFER] ✅ Offer stored for user $userId (will process in acceptCall())');
              break; // Exit early - answer will be created in acceptCall()
            }
            
            // Call is accepted - proceed with getting local stream and creating answer
            print('🔵 [OFFER] ✅ Call is accepted - getting local stream and creating answer...');
            
            // Get local media stream (include video for video calls)
            final includeVideo = _currentCallType == CallType.video;
            print('🔵 [OFFER] Getting local stream (includeVideo: $includeVideo) for recipient...');
            final localStream = await _getLocalStream(
              includeVideo: includeVideo,
              context: null, // Context not available in signal handler
            );
            print('🔵 [OFFER] Local stream obtained, checking if tracks are added...');
            
            // Check if tracks are already added
            final senders = await peerConnection!.getSenders();
            final hasLocalTracks = senders.any((sender) => sender.track != null);
            
            if (!hasLocalTracks) {
              print('🔵 [OFFER] Adding local stream tracks to peer connection...');
              localStream.getTracks().forEach((track) {
                print('🔵 [OFFER] Adding track: ${track.kind}, enabled: ${track.enabled}');
                peerConnection!.addTrack(track, localStream);
              });
              print('🔵 [OFFER] Added ${localStream.getTracks().length} local tracks to peer connection for $userId');
            } else {
              print('🔵 [OFFER] Local tracks already added to peer connection');
            }
            
            // Set remote description if not already set
            try {
              final existingRemoteDesc = await peerConnection!.getRemoteDescription();
              if (existingRemoteDesc == null) {
                await peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
                print('🔵 [OFFER] ✅ Remote description set successfully');
              } else {
                print('🔵 [OFFER] Remote description already set');
              }
            } catch (e) {
              print('❌ [OFFER] ERROR setting remote description: $e');
              Log.e('Error setting remote description', 'WEBRTC_CALL_SERVICE', e);
              rethrow;
            }
            
            // Wait a moment for remote description to be processed
            await Future.delayed(const Duration(milliseconds: 200));
            
            // Verify tracks are still in the peer connection before creating answer
            final sendersBeforeAnswer = await peerConnection.getSenders();
            print('🔵 [OFFER] Senders count before creating answer: ${sendersBeforeAnswer.length}');
            for (final sender in sendersBeforeAnswer) {
              print('🔵 [OFFER]   Sender track: ${sender.track?.kind}, enabled: ${sender.track?.enabled}, id: ${sender.track?.id}');
            }
            
            // Create answer (tracks are already added, so SDP will include media)
            print('🔵 [OFFER] Creating answer (tracks should be in SDP)...');
            RTCSessionDescription answer;
            try {
              answer = await peerConnection.createAnswer();
              print('🔵 [OFFER] ✅ Answer created, SDP length: ${answer.sdp?.length ?? 0}');
            } catch (e) {
              print('❌ [OFFER] ERROR creating answer: $e');
              Log.e('Error creating answer', 'WEBRTC_CALL_SERVICE', e);
              rethrow;
            }
            
            // Verify tracks are in the answer SDP BEFORE setting local description
            if (answer.sdp != null) {
              final hasAudio = answer.sdp!.contains('m=audio');
              final hasVideo = answer.sdp!.contains('m=video');
              print('🔵 [OFFER] Answer SDP contains - Audio: $hasAudio, Video: $hasVideo');
              if (!hasAudio && !hasVideo) {
                print('⚠️ [OFFER] WARNING: Answer SDP does not contain media! This might cause no media streams.');
                print('⚠️ [OFFER] Senders count: ${sendersBeforeAnswer.length}');
                Log.w('Answer SDP does not contain media tracks - sending anyway', 'WEBRTC_CALL_SERVICE');
                // Still send the answer - sometimes SDP format varies and media might still work
                // The peer connection will handle it
              }
            }
            
            // Set local description
            try {
              await peerConnection.setLocalDescription(answer);
              print('🔵 [OFFER] ✅ Local description set');
            } catch (e) {
              print('❌ [OFFER] ERROR setting local description: $e');
              Log.e('Error setting local description', 'WEBRTC_CALL_SERVICE', e);
              rethrow;
            }
            
            // Send answer signal
            print('🔵 [OFFER] Sending answer signal to $userId...');
            print('🔵 [OFFER] Answer SDP preview: ${answer.sdp?.substring(0, answer.sdp!.length > 200 ? 200 : answer.sdp!.length)}...');
            print('🔵 [OFFER] Call ID: $callId, Target User ID: $userId');
            try {
              await sendWebRTCSignal('answer', {
                'answer': {
                  'sdp': answer.sdp,
                  'type': answer.type,
                },
              }, callId: callId, targetUserId: userId); // Send to specific user
              print('🔵 [OFFER] ✅ Answer signal sent successfully to $userId');
            } catch (e, stackTrace) {
              print('❌ [OFFER] ERROR sending answer signal: $e');
              print('❌ [OFFER] Stack trace: $stackTrace');
              Log.e('Error sending answer signal', 'WEBRTC_CALL_SERVICE', e, stackTrace);
              rethrow; // Re-throw to see the error
            }
            print('🔵 [OFFER] ✅ Answer created and sent to $userId');
            
            // Verify tracks are in the answer SDP
            if (answer.sdp != null) {
              final hasAudio = answer.sdp!.contains('m=audio');
              final hasVideo = answer.sdp!.contains('m=video');
              print('🔵 [OFFER] Answer SDP contains - Audio: $hasAudio, Video: $hasVideo');
              if (!hasAudio && !hasVideo) {
                print('⚠️ [OFFER] WARNING: Answer SDP does not contain media! This will cause no media streams.');
                Log.w('Answer SDP does not contain media tracks', 'WEBRTC_CALL_SERVICE');
              }
            }
          } else {
            print('❌ [OFFER] No offer data found in signal');
            Log.e('No offer data found in signal', 'WEBRTC_CALL_SERVICE');
          }
          break;
        case 'answer':
          // Handle answer signal - server sends {callId, userId, answer: {sdp, type}}
          final answer = signalData['answer'];
          
          if (answer != null && answer is Map) {
            if (peerConnection == null) {
              print('❌ [ANSWER] No peer connection found for answer from user: $userId');
              Log.w('No peer connection found for answer from user: $userId', 'WEBRTC_CALL_SERVICE');
              return;
            }
            print('🔵 [ANSWER] Setting remote description from answer...');
            print('🔵 [ANSWER] Answer SDP length: ${answer['sdp']?.toString().length ?? 0}');
            
            // Verify answer SDP contains media
            if (answer['sdp'] != null) {
              final sdpStr = answer['sdp'].toString();
              final hasAudio = sdpStr.contains('m=audio');
              final hasVideo = sdpStr.contains('m=video');
              print('🔵 [ANSWER] Answer SDP contains - Audio: $hasAudio, Video: $hasVideo');
              if (!hasAudio && !hasVideo) {
                print('⚠️ [ANSWER] WARNING: Answer SDP does not contain media! This will cause no media streams.');
                Log.w('Answer SDP does not contain media tracks', 'WEBRTC_CALL_SERVICE');
              }
            }
            
            try {
              await peerConnection.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
              print('🔵 [ANSWER] ✅ Remote description set from answer');
            } catch (e) {
              print('❌ [ANSWER] ERROR setting remote description: $e');
              Log.e('Error setting remote description from answer', 'WEBRTC_CALL_SERVICE', e);
              rethrow;
            }
            
            // After setting remote description, ICE connection should start
            // Media streams should start flowing once ICE connection is established
            print('🔵 [ANSWER] Waiting for ICE connection to establish...');
            
            // Verify that we have local tracks in the peer connection
            final senders = await peerConnection.getSenders();
            print('🔵 [ANSWER] Local senders count: ${senders.length}');
            for (final sender in senders) {
              print('🔵 [ANSWER]   Sender track: ${sender.track?.kind}, enabled: ${sender.track?.enabled}, id: ${sender.track?.id}');
            }
          } else {
            print('❌ [ANSWER] No answer data found in signal');
            Log.e('No answer data found in signal', 'WEBRTC_CALL_SERVICE');
          }
          break;
        case 'ice-candidate':
          // Handle ICE candidate - server sends {callId, userId, candidate: {candidate, sdpMid, sdpMLineIndex}}
          final candidateData = signalData['candidate'];
          
          if (candidateData != null && candidateData is Map) {
            if (peerConnection == null) {
              print('❌ [ICE] No peer connection found for ICE candidate from user: $userId');
              Log.w('No peer connection found for ICE candidate from user: $userId', 'WEBRTC_CALL_SERVICE');
              return;
            }
            final candidateStr = candidateData['candidate'];
            final sdpMid = candidateData['sdpMid'];
            final sdpMLineIndex = candidateData['sdpMLineIndex'];
            
            if (candidateStr != null) {
              final candidatePreview = candidateStr.length > 50 ? candidateStr.substring(0, 50) : candidateStr;
              print('🔵 [ICE] Adding ICE candidate from $userId: $candidatePreview...');
              try {
                await peerConnection.addCandidate(RTCIceCandidate(
                  candidateStr,
                  sdpMid,
                  sdpMLineIndex,
                ));
                print('🔵 [ICE] ICE candidate added successfully');
              } catch (e) {
                print('❌ [ICE] Error adding ICE candidate: $e');
                Log.e('Error adding ICE candidate', 'WEBRTC_CALL_SERVICE', e);
              }
            } else {
              print('❌ [ICE] No candidate string found in signal');
              Log.e('No candidate string found in signal', 'WEBRTC_CALL_SERVICE');
            }
          } else {
            print('❌ [ICE] No candidate data found in signal');
            Log.e('No candidate data found in signal', 'WEBRTC_CALL_SERVICE');
          }
          break;
      }
      
      Log.i('Processed WebRTC signal: $type from $userId', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error handling WebRTC signal', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Create and configure a peer connection
  /// This works across all platforms (mobile via ngrok, web via proxy)
  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    final platform = kIsWeb ? 'Web' : 'Mobile';
    Log.i('Creating peer connection for user $userId from $platform', 'WEBRTC_CALL_SERVICE');
    
    // Log ICE servers being used
    print('🔵 [PEER_CONNECTION] ICE servers configuration:');
    for (final server in _iceServers) {
      final urls = server['urls']?.toString() ?? 'unknown';
      final hasCredentials = server['username'] != null && server['credential'] != null;
      print('   - $urls (${hasCredentials ? "with credentials" : "no credentials"})');
    }
    Log.i('ICE Servers: ${_iceServers.map((s) => s['urls']).join(", ")}', 'WEBRTC_CALL_SERVICE');
    
    final configuration = {
      'iceServers': _iceServers,
      // Enable ICE candidate gathering for cross-platform calls
      'iceCandidatePoolSize': 10,
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final peerConnection = await createPeerConnection(configuration, constraints);
    
    Log.i('Peer connection created for $userId', 'WEBRTC_CALL_SERVICE');

    // Handle ICE candidates
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        // Log ICE candidate type to see if TURN (relay) is being used
        final candidateStr = candidate.candidate ?? '';
        if (candidateStr.contains('typ relay')) {
          print('🔵 [ICE_CANDIDATE] ✅ RELAY candidate (TURN server) from $userId: ${candidateStr.substring(0, candidateStr.length > 100 ? 100 : candidateStr.length)}...');
          Log.i('RELAY ICE candidate (TURN) from $userId', 'WEBRTC_CALL_SERVICE');
        } else if (candidateStr.contains('typ srflx')) {
          print('🔵 [ICE_CANDIDATE] Server reflexive candidate (STUN) from $userId');
        } else if (candidateStr.contains('typ host')) {
          print('🔵 [ICE_CANDIDATE] Host candidate (local) from $userId');
        } else {
          print('🔵 [ICE_CANDIDATE] Candidate from $userId: ${candidateStr.substring(0, candidateStr.length > 100 ? 100 : candidateStr.length)}...');
        }
        
        sendWebRTCSignal('ice_candidate', {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        }, targetUserId: userId); // Send to specific user
      }
    };

    // Handle remote stream (legacy API - for compatibility)
    peerConnection.onAddStream = (MediaStream stream) {
      print('🔵 [ON_ADD_STREAM] ========== REMOTE STREAM RECEIVED ==========');
      print('🔵 [ON_ADD_STREAM] From user: $userId');
      print('🔵 [ON_ADD_STREAM] Stream ID: ${stream.id}');
      print('🔵 [ON_ADD_STREAM] Audio tracks: ${stream.getAudioTracks().length}');
      print('🔵 [ON_ADD_STREAM] Video tracks: ${stream.getVideoTracks().length}');
      
      // Store the stream
      _remoteStreams[userId] = stream;
      print('🔵 [ON_ADD_STREAM] Stream stored in _remoteStreams for $userId');
      
      // Trigger callback to update UI
      if (onRemoteStream != null) {
        print('🔵 [ON_ADD_STREAM] Triggering onRemoteStream callback...');
        onRemoteStream!.call(userId, stream);
        print('🔵 [ON_ADD_STREAM] ✅ Callback triggered - UI should update now!');
      } else {
        print('⚠️ [ON_ADD_STREAM] WARNING: onRemoteStream callback is null!');
      }
      
      Log.i('Remote stream received from $userId via onAddStream', 'WEBRTC_CALL_SERVICE');
      print('🔵 [ON_ADD_STREAM] ===========================================');
    };

    // Handle remote track (modern API)
    peerConnection.onTrack = (RTCTrackEvent event) {
      print('🔵 [ON_TRACK] ========== REMOTE TRACK RECEIVED ==========');
      print('🔵 [ON_TRACK] From user: $userId');
      print('🔵 [ON_TRACK] Track kind: ${event.track?.kind}');
      print('🔵 [ON_TRACK] Track enabled: ${event.track?.enabled}');
      print('🔵 [ON_TRACK] Track id: ${event.track?.id}');
      print('🔵 [ON_TRACK] Streams count: ${event.streams?.length ?? 0}');
      
      if (event.streams != null && event.streams!.isNotEmpty) {
        // Streams are present in the event - this is the normal case
        final stream = event.streams![0];
        print('🔵 [ON_TRACK] ✅ Stream found in event!');
        print('🔵 [ON_TRACK] Stream ID: ${stream.id}');
        print('🔵 [ON_TRACK] Audio tracks: ${stream.getAudioTracks().length}');
        print('🔵 [ON_TRACK] Video tracks: ${stream.getVideoTracks().length}');
        
        // Store the stream
        _remoteStreams[userId] = stream;
        print('🔵 [ON_TRACK] Stream stored in _remoteStreams for $userId');
        
        // Trigger callback to update UI
        if (onRemoteStream != null) {
          print('🔵 [ON_TRACK] Triggering onRemoteStream callback...');
          onRemoteStream!.call(userId, stream);
          print('🔵 [ON_TRACK] ✅ Callback triggered - UI should update now!');
        } else {
          print('⚠️ [ON_TRACK] WARNING: onRemoteStream callback is null!');
        }
        
        Log.i('Remote track received from $userId (${event.track?.kind}) - stream available', 'WEBRTC_CALL_SERVICE');
      } else if (event.track != null) {
        // No streams in event, but we have a track
        // This can happen in some WebRTC implementations
        print('🔵 [ON_TRACK] ⚠️ No streams in event, but track exists');
        print('🔵 [ON_TRACK] Track kind: ${event.track?.kind}, id: ${event.track?.id}');
        
        // Check if we already have a stream for this user
        MediaStream? existingStream = _remoteStreams[userId];
        
        if (existingStream != null) {
          // Add track to existing stream
          print('🔵 [ON_TRACK] Adding track to existing stream for $userId');
          try {
            existingStream.addTrack(event.track!);
            print('🔵 [ON_TRACK] Track added to existing stream');
            
            // Trigger callback
            if (onRemoteStream != null) {
              onRemoteStream!.call(userId, existingStream);
              print('🔵 [ON_TRACK] Callback triggered with updated stream');
            }
          } catch (e) {
            print('❌ [ON_TRACK] Error adding track to existing stream: $e');
            Log.e('Error adding track to existing stream', 'WEBRTC_CALL_SERVICE', e);
          }
        } else {
          // No existing stream - get receivers from peer connection to create stream
          print('🔵 [ON_TRACK] No existing stream - getting receivers to create stream');
          // Use Future.microtask to handle async operation in callback
          Future.microtask(() async {
            try {
              // Get all receivers from the peer connection
              final receivers = await peerConnection.getReceivers();
              print('🔵 [ON_TRACK] Found ${receivers.length} receivers');
              
              // Collect all tracks from receivers
              final audioTracks = <MediaStreamTrack>[];
              final videoTracks = <MediaStreamTrack>[];
              
              for (final receiver in receivers) {
                if (receiver.track != null) {
                  if (receiver.track!.kind == 'audio') {
                    audioTracks.add(receiver.track!);
                  } else if (receiver.track!.kind == 'video') {
                    videoTracks.add(receiver.track!);
                  }
                }
              }
              
              if (audioTracks.isEmpty && videoTracks.isEmpty) {
                print('⚠️ [ON_TRACK] No tracks found in receivers - waiting for more tracks');
                return;
              }
              
              // Create a stream using the navigator helper
              // For remote streams, we create a local stream and replace its tracks
              final newStream = await createLocalMediaStream('remote_$userId');
              
              // Remove any existing tracks from the stream (it might have local tracks)
              for (final track in newStream.getTracks()) {
                newStream.removeTrack(track);
              }
              
              // Add all remote tracks to the stream
              for (final track in audioTracks) {
                newStream.addTrack(track);
              }
              for (final track in videoTracks) {
                newStream.addTrack(track);
              }
              
              print('🔵 [ON_TRACK] Created new stream with ${audioTracks.length} audio and ${videoTracks.length} video tracks');
              print('🔵 [ON_TRACK] Stream ID: ${newStream.id}');
              
              // Store the stream
              _remoteStreams[userId] = newStream;
              print('🔵 [ON_TRACK] Stream stored in _remoteStreams for $userId');
              
              // Trigger callback to update UI
              if (onRemoteStream != null) {
                print('🔵 [ON_TRACK] Triggering onRemoteStream callback...');
                onRemoteStream!.call(userId, newStream);
                print('🔵 [ON_TRACK] ✅ Callback triggered - UI should update now!');
              } else {
                print('⚠️ [ON_TRACK] WARNING: onRemoteStream callback is null!');
              }
              
              Log.i('Remote track received without stream from $userId - created new stream from receivers', 'WEBRTC_CALL_SERVICE');
            } catch (e) {
              print('❌ [ON_TRACK] Error creating stream from receivers: $e');
              Log.e('Error creating stream from receivers', 'WEBRTC_CALL_SERVICE', e);
            }
          });
        }
      } else {
        print('❌ [ON_TRACK] ERROR: No track and no streams in event!');
        Log.w('Remote track event received but no track or streams', 'WEBRTC_CALL_SERVICE');
      }
      print('🔵 [ON_TRACK] ===========================================');
    };

    // Handle ICE connection state changes
    peerConnection.onIceConnectionState = (RTCIceConnectionState state) {
      print('🔵 [ICE_CONNECTION] State changed to $state for user $userId');
      Log.i('ICE connection state changed: $state for user $userId', 'WEBRTC_CALL_SERVICE');
      
      // Log ICE gathering state to see if TURN servers are being used
      peerConnection.onIceGatheringState = (RTCIceGatheringState gatheringState) {
        print('🔵 [ICE_GATHERING] Gathering state: $gatheringState for user $userId');
        if (gatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          print('🔵 [ICE_GATHERING] ✅ ICE gathering complete - check logs above for RELAY candidates (TURN usage)');
        }
      };
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('🔵 [ICE_CONNECTION] ✅ Connection established with $userId - media should flow now!');
        print('🔵 [ICE_CONNECTION] Remote streams count: ${_remoteStreams.length}');
        
        // Check if TURN server was used by examining ICE connection type
        // This helps diagnose if TURN is working for cross-network calls
        print('🔵 [ICE_CONNECTION] Check logs above for "RELAY candidate" to confirm TURN server usage');
        Log.i('ICE connection established with $userId - media should flow', 'WEBRTC_CALL_SERVICE');
        
        // Cancel any pending reconnection attempts
        _reconnectionTimers[userId]?.cancel();
        _reconnectionTimers.remove(userId);
        _reconnectionAttempts.remove(userId);
        
        // Check if we have remote streams
        if (_remoteStreams.containsKey(userId)) {
          print('🔵 [ICE_CONNECTION] Remote stream exists for $userId');
        } else {
          print('⚠️ [ICE_CONNECTION] WARNING: No remote stream yet for $userId - waiting for onTrack event');
        }
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
        print('🔵 [ICE_CONNECTION] Checking connection with $userId...');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print('🔵 [ICE_CONNECTION] ❌ Connection lost with $userId - attempting reconnection...');
        Log.w('ICE connection lost with $userId - attempting reconnection', 'WEBRTC_CALL_SERVICE');
        
        // Don't remove remote stream immediately - keep it for reconnection
        // Only attempt reconnection if call is still active
        if (_currentCallId != null && _isInCall) {
          _attemptReconnection(userId, peerConnection);
        } else {
          _remoteStreams.remove(userId);
        }
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        print('🔵 [ICE_CONNECTION] Connection closed with $userId');
        _remoteStreams.remove(userId);
        _reconnectionTimers[userId]?.cancel();
        _reconnectionTimers.remove(userId);
        _reconnectionAttempts.remove(userId);
      }
    };

    // Handle connection state changes
    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      print('🔵 [CONNECTION] State changed to $state for user $userId');
      Log.i('Peer connection state changed: $state for user $userId', 'WEBRTC_CALL_SERVICE');
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('🔵 [CONNECTION] ✅ Peer connection connected with $userId');
        // Cancel any pending reconnection attempts
        _reconnectionTimers[userId]?.cancel();
        _reconnectionTimers.remove(userId);
        _reconnectionAttempts.remove(userId);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        print('🔵 [CONNECTION] ❌ Peer connection lost with $userId - attempting reconnection...');
        // Don't remove remote stream immediately - keep it for reconnection
        if (_currentCallId != null && _isInCall) {
          _attemptReconnection(userId, peerConnection);
        } else {
          _remoteStreams.remove(userId);
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('🔵 [CONNECTION] Peer connection closed with $userId');
        _remoteStreams.remove(userId);
        _reconnectionTimers[userId]?.cancel();
        _reconnectionTimers.remove(userId);
        _reconnectionAttempts.remove(userId);
      }
    };

    return peerConnection;
  }

  /// Get local media stream (audio and/or video)
  /// Requests permissions before accessing media (required for Android 13+)
  Future<MediaStream> _getLocalStream({bool includeVideo = true, BuildContext? context}) async {
    if (_localStream != null) {
      // Ensure callback is called even if stream already exists
      onLocalStream?.call(_localStream!);
      return _localStream!;
    }

    // Get context from navigator key if not provided
    BuildContext? effectiveContext = context;
    if (effectiveContext == null && navigatorKey.currentContext != null) {
      effectiveContext = navigatorKey.currentContext;
    }

    // Request permissions before accessing media (critical for Android 13+)
    print('🔵 [PERMISSION] Requesting call permissions (includeVideo: $includeVideo)...');
    final hasPermissions = await CallPermissionService.requestCallPermissions(
      context: effectiveContext,
      includeVideo: includeVideo,
    );
    
    if (!hasPermissions) {
      final errorMsg = includeVideo
          ? 'Camera and microphone permissions are required for video calls'
          : 'Microphone permission is required for voice calls';
      print('❌ [PERMISSION] $errorMsg');
      Log.e(errorMsg, 'WEBRTC_CALL_SERVICE');
      throw Exception(errorMsg);
    }
    
    print('✅ [PERMISSION] All required permissions granted');

    final constraints = <String, dynamic>{
      'audio': true,
      'video': includeVideo ? {
        'facingMode': 'user',
        'width': {'min': 640, 'ideal': 1280},
        'height': {'min': 480, 'ideal': 720},
      } : false,
    };

    print('🔵 [LOCAL_STREAM] Requesting media stream from device...');
    _localStream = await navigator.getUserMedia(constraints);
    print('🔵 [LOCAL_STREAM] Local media stream obtained');
    print('🔵 [LOCAL_STREAM] Audio tracks: ${_localStream!.getAudioTracks().length}');
    print('🔵 [LOCAL_STREAM] Video tracks: ${_localStream!.getVideoTracks().length}');
    
    // Always trigger callback to ensure UI updates
    if (onLocalStream != null) {
      print('🔵 [LOCAL_STREAM] Triggering onLocalStream callback...');
      onLocalStream!.call(_localStream!);
      print('🔵 [LOCAL_STREAM] ✅ Callback triggered');
    } else {
      print('⚠️ [LOCAL_STREAM] WARNING: onLocalStream callback is null!');
    }
    
    Log.i('Local media stream obtained', 'WEBRTC_CALL_SERVICE');
    
    // Enable speaker by default for better audio experience
    if (!kIsWeb) {
      try {
        _isSpeakerOn = true;
        await Helper.setSpeakerphoneOn(true);
        print('🔵 Speaker enabled by default');
        Log.i('Speaker enabled by default', 'WEBRTC_CALL_SERVICE');
      } catch (e) {
        print('🔵 Could not enable speaker by default: $e');
        Log.w('Could not enable speaker by default', 'WEBRTC_CALL_SERVICE');
        _isSpeakerOn = false;
      }
    }
    
    return _localStream!;
  }

  /// Start screen sharing
  Future<bool> startScreenShare() async {
    try {
      if (_isScreenSharing) {
        Log.w('Screen sharing already active', 'WEBRTC_CALL_SERVICE');
        return true;
      }

      if (_currentCallId == null || _peerConnections.isEmpty) {
        Log.e('Cannot start screen share: No active call', 'WEBRTC_CALL_SERVICE');
        return false;
      }

      // Get screen sharing stream
      final constraints = <String, dynamic>{
        'audio': false, // Screen share typically doesn't include audio
        'video': {
          'mandatory': {
            'chromeMediaSource': 'screen',
          },
        },
      };

      // For web, use getDisplayMedia
      if (kIsWeb) {
        _screenShareStream = await navigator.getDisplayMedia(constraints);
      } else {
        // For mobile, screen sharing may not be fully supported
        // Try to get display media if available
        try {
          _screenShareStream = await navigator.getDisplayMedia(constraints);
        } catch (e) {
          Log.w('Screen sharing not supported on this platform: $e', 'WEBRTC_CALL_SERVICE');
          return false;
        }
      }

      if (_screenShareStream == null) {
        Log.e('Failed to get screen share stream', 'WEBRTC_CALL_SERVICE');
        return false;
      }

      // Replace video tracks in all peer connections with screen share tracks
      for (final entry in _peerConnections.entries) {
        final peerConnection = entry.value;
        final screenShareTracks = _screenShareStream!.getVideoTracks();
        
        // Remove existing video tracks
        final senders = await peerConnection.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await peerConnection.removeTrack(sender);
          }
        }
        
        // Add screen share video tracks
        for (final track in screenShareTracks) {
          await peerConnection.addTrack(track, _screenShareStream!);
        }
      }

      _isScreenSharing = true;
      Log.i('Screen sharing started', 'WEBRTC_CALL_SERVICE');
      return true;
    } catch (e, stackTrace) {
      Log.e('Error starting screen share', 'WEBRTC_CALL_SERVICE', e, stackTrace);
      return false;
    }
  }

  /// Stop screen sharing
  Future<bool> stopScreenShare() async {
    try {
      if (!_isScreenSharing || _screenShareStream == null) {
        return true;
      }

      // Stop all screen share tracks
      _screenShareStream!.getTracks().forEach((track) {
        track.stop();
      });

      // Restore camera video tracks if we have a local stream
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        for (final entry in _peerConnections.entries) {
          final peerConnection = entry.value;
          
          // Remove screen share tracks
          final senders = await peerConnection.getSenders();
          for (final sender in senders) {
            if (sender.track?.kind == 'video') {
              await peerConnection.removeTrack(sender);
            }
          }
          
          // Add back camera video tracks
          for (final track in videoTracks) {
            await peerConnection.addTrack(track, _localStream!);
          }
        }
      }

      _screenShareStream = null;
      _isScreenSharing = false;
      Log.i('Screen sharing stopped', 'WEBRTC_CALL_SERVICE');
      return true;
    } catch (e, stackTrace) {
      Log.e('Error stopping screen share', 'WEBRTC_CALL_SERVICE', e, stackTrace);
      return false;
    }
  }

  /// Check if screen sharing is active
  bool get isScreenSharing => _isScreenSharing;

  /// Start a call (voice or video)
  Future<String?> startCall({
    required String chatId,
    required String chatName,
    required List<String> participantIds,
    required CallType callType,
    bool isGroupChat = false,
  }) async {
    try {
      print('🔵 WebRTC startCall called');
      if (_currentUserId == null) {
        print('❌ Cannot start call: User not authenticated');
        Log.e('Cannot start call: User not authenticated', 'WEBRTC_CALL_SERVICE');
        return null;
      }
      print('🔵 Current user ID: $_currentUserId');

      if (participantIds.isEmpty) {
        print('❌ Cannot start call: No participants');
        Log.e('Cannot start call: No participants', 'WEBRTC_CALL_SERVICE');
        return null;
      }

      // Filter out current user
      final filteredParticipants = participantIds.where((id) => id != _currentUserId).toList();
      if (filteredParticipants.isEmpty) {
        print('❌ Cannot start call: No valid participants');
        Log.e('Cannot start call: No valid participants', 'WEBRTC_CALL_SERVICE');
        return null;
      }
      print('🔵 Filtered participants: ${filteredParticipants.join(", ")}');

      // Generate unique call ID
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
      print('🔵 Generated call ID: $callId');
      
      // Set current call ID early so WebRTC signals can be sent
      _currentCallId = callId;
      _currentCallType = callType;
      _callStartTime = DateTime.now();
      _currentChatId = chatId;
      _currentChatName = chatName;
      _currentParticipantIds = filteredParticipants;
      _currentIsGroupChat = isGroupChat;
      print('🔵 Set current call ID and type');

      // Get local media stream (include video for video calls)
      print('🔵 Getting local media stream (includeVideo: ${callType == CallType.video})...');
      MediaStream localStream;
      try {
        // Note: Context is not available here, but permission service will still request permissions
        // The settings dialog will only show if permission is permanently denied and user tries again
        localStream = await _getLocalStream(
          includeVideo: callType == CallType.video,
          context: null, // Context not available in service, but permissions will still be requested
        );
        print('🔵 Local media stream obtained');
      } catch (e) {
        print('❌ Error getting local media stream: $e');
        Log.e('Error getting local media stream', 'WEBRTC_CALL_SERVICE', e);
        _resetCallState();
        return null;
      }

      // Join call room for signaling
      print('🔵 Joining call room: call:$callId');
      _realtime.emit('join_call', {'callId': callId});
      print('🔵 Joined call room');

      // Create peer connections for each participant
      print('🔵 Creating peer connections for ${filteredParticipants.length} participants...');
      for (final participantId in filteredParticipants) {
        print('🔵 Creating peer connection for participant: $participantId');
        final peerConnection = await _createPeerConnection(participantId);
        _peerConnections[participantId] = peerConnection;
        print('🔵 Peer connection created for $participantId');

        // Add local stream tracks to peer connection
        print('🔵 [CALLER] Adding local stream tracks to peer connection for $participantId...');
        localStream.getTracks().forEach((track) {
          print('🔵 [CALLER] Adding track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
          peerConnection.addTrack(track, localStream);
        });
        print('🔵 [CALLER] ✅ Added ${localStream.getTracks().length} local stream tracks to peer connection');

        // Create and send offer
        // CRITICAL: Tracks must be added BEFORE creating offer
        print('🔵 [CALLER] Creating offer for $participantId...');
        print('🔵 [CALLER] Verifying tracks are added before creating offer...');
        final sendersBeforeOffer = await peerConnection.getSenders();
        print('🔵 [CALLER] Senders count: ${sendersBeforeOffer.length}');
        for (final sender in sendersBeforeOffer) {
          print('🔵 [CALLER]   Sender track: ${sender.track?.kind}, enabled: ${sender.track?.enabled}, id: ${sender.track?.id}');
        }
        
        RTCSessionDescription offer;
        try {
          offer = await peerConnection.createOffer();
          print('🔵 [CALLER] ✅ Offer created, SDP length: ${offer.sdp?.length ?? 0}');
        } catch (e) {
          print('❌ [CALLER] ERROR creating offer: $e');
          Log.e('Error creating offer', 'WEBRTC_CALL_SERVICE', e);
          continue; // Skip this participant and continue with others
        }
        
        // Verify tracks are in the offer SDP BEFORE setting local description
        if (offer.sdp != null) {
          final hasAudio = offer.sdp!.contains('m=audio');
          final hasVideo = offer.sdp!.contains('m=video');
          print('🔵 [CALLER] Offer SDP contains - Audio: $hasAudio, Video: $hasVideo');
          if (!hasAudio && !hasVideo) {
            print('⚠️ [CALLER] WARNING: Offer SDP does not contain media! This might cause no media streams.');
            print('⚠️ [CALLER] Senders count: ${sendersBeforeOffer.length}');
            Log.w('Offer SDP does not contain media tracks - sending anyway', 'WEBRTC_CALL_SERVICE');
            // Still send the offer - sometimes SDP format varies and media might still work
          }
        } else {
          print('❌ [CALLER] ERROR: Offer SDP is null!');
          Log.e('Offer SDP is null', 'WEBRTC_CALL_SERVICE');
          continue; // Skip this participant and continue with others
        }
        
        try {
          await peerConnection.setLocalDescription(offer);
          print('🔵 [CALLER] ✅ Offer set as local description');
        } catch (e) {
          print('❌ [CALLER] ERROR setting local description: $e');
          Log.e('Error setting local description', 'WEBRTC_CALL_SERVICE', e);
          continue; // Skip this participant and continue with others
        }
        
        try {
          await sendWebRTCSignal('offer', {
            'offer': {
              'sdp': offer.sdp,
              'type': offer.type,
            },
          }, callId: callId, targetUserId: participantId); // Send to specific participant
          print('🔵 [CALLER] ✅ WebRTC offer signal sent for $participantId');
        } catch (e) {
          print('❌ [CALLER] ERROR sending offer signal: $e');
          Log.e('Error sending offer signal', 'WEBRTC_CALL_SERVICE', e);
          // Continue with other participants even if one fails
        }
      }
      print('🔵 All peer connections created');

      // Send call invitation via API
      print('🔵 Getting auth token...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        print('❌ Cannot start call: No auth token');
        Log.e('Cannot start call: No auth token', 'WEBRTC_CALL_SERVICE');
        return null;
      }
      print('🔵 Auth token obtained');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/start';
      
      // Log platform and URL for debugging
      final platform = kIsWeb ? 'Web' : 'Mobile';
      print('🔵 Starting call from $platform platform');
      print('🔵 API URL: $url');
      print('🔵 Call Type: ${callType == CallType.voice ? "Voice" : "Video"}');
      print('🔵 Participants: ${filteredParticipants.length} (${filteredParticipants.join(", ")})');
      Log.i('Starting call from $platform platform', 'WEBRTC_CALL_SERVICE');
      Log.i('API URL: $url', 'WEBRTC_CALL_SERVICE');
      Log.i('Call Type: ${callType == CallType.voice ? "Voice" : "Video"}', 'WEBRTC_CALL_SERVICE');
      Log.i('Participants: ${filteredParticipants.length} (${filteredParticipants.join(", ")})', 'WEBRTC_CALL_SERVICE');

      // Build headers with platform-specific requirements
      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      // Add ngrok header for mobile (ngrok) requests
      if (!kIsWeb) {
        headers['ngrok-skip-browser-warning'] = 'true';
      }

      print('🔵 Sending API request to start call...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'callId': callId,
          'chatId': chatId,
          'chatName': chatName,
          'callerId': _currentUserId,
          'callType': callType == CallType.voice ? 'voice' : 'video',
          'participantIds': filteredParticipants,
          'isGroupChat': isGroupChat,
        }),
      ).timeout(const Duration(seconds: 10));

      print('🔵 API Response Status: ${response.statusCode}');
      print('🔵 API Response Body: ${response.body}');
      Log.i('API Response Status: ${response.statusCode}', 'WEBRTC_CALL_SERVICE');
      Log.i('API Response Body: ${response.body}', 'WEBRTC_CALL_SERVICE');
      
      if (response.statusCode == 200) {
        _currentCallId = callId;
        _currentCallType = callType;
        print('✅ Call started successfully: $callId');
        Log.i('✅ Call started successfully: $callId', 'WEBRTC_CALL_SERVICE');
        return callId;
      } else {
        print('❌ Failed to start call: ${response.statusCode} - ${response.body}');
        Log.e('❌ Failed to start call: ${response.statusCode} - ${response.body}', 'WEBRTC_CALL_SERVICE');
        await _cleanup();
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error starting call: $e');
      print('❌ Stack trace: $stackTrace');
      Log.e('Error starting call', 'WEBRTC_CALL_SERVICE', e, stackTrace);
      await _cleanup();
      return null;
    }
  }

  /// Accept an incoming call
  Future<bool> acceptCall(String callId) async {
    try {
      print('🔵 [ACCEPT] Accepting call: $callId');
      if (!_realtime.isConnected) {
        print('❌ [ACCEPT] Cannot accept call: Not connected');
        return false;
      }

      // Set current call ID and type before handling offers
      _currentCallId = callId;
      // Set _isInCall early so offer handler knows call is accepted
      _isInCall = true;
      print('🔵 [ACCEPT] Current call ID set: $callId, call type: $_currentCallType, _isInCall: $_isInCall');

      // Join call room for signaling
      print('🔵 [ACCEPT] Joining call room: call:$callId');
      _realtime.emit('join_call', {'callId': callId});
      print('🔵 [ACCEPT] Joined call room');

      // Get local media stream (include video for video calls)
      final includeVideo = _currentCallType == CallType.video;
      print('🔵 [ACCEPT] Getting local media stream (includeVideo: $includeVideo)...');
      // Note: Context is not available here, but permission service will still request permissions
      final localStream = await _getLocalStream(
        includeVideo: includeVideo,
        context: null, // Context not available in service, but permissions will still be requested
      );
      print('🔵 [ACCEPT] Local media stream obtained: ${localStream.getTracks().length} tracks');
      print('🔵 [ACCEPT] Audio tracks: ${localStream.getAudioTracks().length}');
      print('🔵 [ACCEPT] Video tracks: ${localStream.getVideoTracks().length}');
      
      // First, process any pending offers (offers that arrived before acceptance)
      print('🔵 [ACCEPT] Checking for pending offers: ${_pendingOffers.length} found');
      for (final entry in _pendingOffers.entries) {
        final userId = entry.key;
        final pendingData = entry.value;
        final offer = pendingData['offer'] as Map<String, dynamic>;
        final offerCallId = pendingData['callId'] as String?;
        
        print('🔵 [ACCEPT] Processing pending offer from $userId for call $offerCallId');
        
        // Create peer connection if it doesn't exist
        RTCPeerConnection? peerConnection = _peerConnections[userId];
        if (peerConnection == null) {
          print('🔵 [ACCEPT] Creating peer connection for $userId');
          peerConnection = await _createPeerConnection(userId);
          _peerConnections[userId] = peerConnection;
        }
        
        // Add local tracks FIRST (before setting remote description)
        print('🔵 [ACCEPT] Adding local tracks to peer connection for $userId');
        localStream.getTracks().forEach((track) {
          print('🔵 [ACCEPT] Adding track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
          peerConnection!.addTrack(track, localStream);
        });
        print('🔵 [ACCEPT] ✅ Added ${localStream.getTracks().length} tracks');
        
        // Now set remote description
        print('🔵 [ACCEPT] Setting remote description from stored offer...');
        try {
          await peerConnection.setRemoteDescription(
            RTCSessionDescription(offer['sdp'], offer['type'])
          );
          print('🔵 [ACCEPT] ✅ Remote description set');
        } catch (e, stackTrace) {
          print('❌ [ACCEPT] ERROR setting remote description: $e');
          print('❌ [ACCEPT] Stack trace: $stackTrace');
          Log.e('Error setting remote description in acceptCall', 'WEBRTC_CALL_SERVICE', e, stackTrace);
          continue; // Skip this user and continue with others
        }
        
        // Wait a moment to ensure everything is processed
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Create and send answer
        print('🔵 [ACCEPT] Creating answer...');
        try {
          final answer = await peerConnection.createAnswer();
          print('🔵 [ACCEPT] ✅ Answer created, SDP length: ${answer.sdp?.length ?? 0}');
          
          // Verify answer SDP contains media
          if (answer.sdp != null) {
            final hasAudio = answer.sdp!.contains('m=audio');
            final hasVideo = answer.sdp!.contains('m=video');
            print('🔵 [ACCEPT] Answer SDP contains - Audio: $hasAudio, Video: $hasVideo');
            if (!hasAudio && !hasVideo) {
              print('⚠️ [ACCEPT] WARNING: Answer SDP does not contain media tracks!');
            }
          }
          
          await peerConnection.setLocalDescription(answer);
          print('🔵 [ACCEPT] Local description set from answer');
          
          print('🔵 [ACCEPT] Sending answer signal to $userId...');
          await sendWebRTCSignal('answer', {
            'answer': {
              'sdp': answer.sdp,
              'type': answer.type,
            },
          }, callId: callId, targetUserId: userId);
          print('🔵 [ACCEPT] ✅ Answer sent to $userId');
        } catch (e, stackTrace) {
          print('❌ [ACCEPT] ERROR creating/sending answer: $e');
          print('❌ [ACCEPT] Stack trace: $stackTrace');
          Log.e('Error creating/sending answer in acceptCall', 'WEBRTC_CALL_SERVICE', e, stackTrace);
        }
      }
      
      // Clear pending offers
      _pendingOffers.clear();
      print('🔵 [ACCEPT] Cleared pending offers');
      
      // Also process any existing peer connections (in case offer arrived after acceptance)
      if (_peerConnections.isNotEmpty) {
        print('🔵 [ACCEPT] Processing ${_peerConnections.length} existing peer connection(s)');
        for (final entry in _peerConnections.entries) {
          final userId = entry.key;
          final peerConnection = entry.value;
          
          // Skip if we already processed this user's pending offer
          if (_pendingOffers.containsKey(userId)) {
            continue;
          }
          
          print('🔵 [ACCEPT] Processing existing peer connection for $userId');
          
          // Check if local stream tracks are already added
          final senders = await peerConnection.getSenders();
          final hasLocalTracks = senders.any((sender) => sender.track != null);
          print('🔵 [ACCEPT] Has local tracks: $hasLocalTracks, senders count: ${senders.length}');
          
          if (!hasLocalTracks) {
            print('🔵 [ACCEPT] Adding local tracks to existing peer connection for $userId');
            localStream.getTracks().forEach((track) {
              print('🔵 [ACCEPT] Adding track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
              peerConnection.addTrack(track, localStream);
            });
            print('🔵 [ACCEPT] ✅ Added ${localStream.getTracks().length} tracks to peer connection');
          }
          
          // Check if remote description is set and answer needs to be created
          try {
            final remoteDescription = await peerConnection.getRemoteDescription();
            final localDescription = await peerConnection.getLocalDescription();
            
            print('🔵 [ACCEPT] Remote description: ${remoteDescription != null ? "SET" : "NOT SET"}');
            print('🔵 [ACCEPT] Local description: ${localDescription != null ? "SET" : "NOT SET"}');
            
            if (remoteDescription != null && localDescription == null) {
              print('🔵 [ACCEPT] Remote description set but no local description - creating answer...');
              
              await Future.delayed(const Duration(milliseconds: 200));
              
              final answer = await peerConnection.createAnswer();
              print('🔵 [ACCEPT] ✅ Answer created, SDP length: ${answer.sdp?.length ?? 0}');
              
              if (answer.sdp != null) {
                final hasAudio = answer.sdp!.contains('m=audio');
                final hasVideo = answer.sdp!.contains('m=video');
                print('🔵 [ACCEPT] Answer SDP contains - Audio: $hasAudio, Video: $hasVideo');
              }
              
              await peerConnection.setLocalDescription(answer);
              print('🔵 [ACCEPT] Local description set from answer');
              
              print('🔵 [ACCEPT] Sending answer signal to $userId...');
              await sendWebRTCSignal('answer', {
                'answer': {
                  'sdp': answer.sdp,
                  'type': answer.type,
                },
              }, callId: callId, targetUserId: userId);
              print('🔵 [ACCEPT] ✅ Answer sent to $userId');
            } else if (remoteDescription != null && localDescription != null) {
              print('🔵 [ACCEPT] Both remote and local descriptions are set - answer already sent');
            } else {
              print('🔵 [ACCEPT] No remote description yet - waiting for offer');
            }
          } catch (e, stackTrace) {
            print('❌ [ACCEPT] Error checking/creating answer: $e');
            print('❌ [ACCEPT] Stack trace: $stackTrace');
            Log.e('Error checking/creating answer in acceptCall', 'WEBRTC_CALL_SERVICE', e, stackTrace);
          }
        }
      }

      // Emit call accept event
      _realtime.emit('call_accept', {
        'callId': callId,
        'userId': _currentUserId,
      });
      print('🔵 [ACCEPT] Call accept event emitted');

      // Mark call as answered for history tracking
      markCallAnswered();

      // Don't call callback here - let the server response trigger it
      // This prevents double-triggering
      Log.i('Call accepted: $callId', 'WEBRTC_CALL_SERVICE');
      print('🔵 [ACCEPT] ✅ Call accepted successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ [ACCEPT] Error accepting call: $e');
      print('❌ [ACCEPT] Stack trace: $stackTrace');
      Log.e('Error accepting call', 'WEBRTC_CALL_SERVICE', e, stackTrace);
      _isInCall = false; // Reset on error
      return false;
    }
  }

  /// Reject an incoming call
  Future<bool> rejectCall(String callId) async {
    try {
      if (!_realtime.isConnected) return false;

      _realtime.emit('call_reject', {
        'callId': callId,
        'userId': _currentUserId,
      });

      if (callId == _currentCallId) {
        _resetCallState();
      }
      Log.i('Call rejected: $callId', 'WEBRTC_CALL_SERVICE');
      return true;
    } catch (e) {
      Log.e('Error rejecting call', 'WEBRTC_CALL_SERVICE', e);
      return false;
    }
  }

  /// End the current call
  Future<bool> endCall() async {
    try {
      if (_currentCallId == null) {
        print('❌ [END_CALL] No current call ID');
        return false;
      }
      if (!_realtime.isConnected) {
        print('❌ [END_CALL] Not connected to Socket.IO');
        return false;
      }

      final callId = _currentCallId!;
      print('🔴 [END_CALL] Ending call: $callId');
      
      // Ensure we're in the call room before ending
      _realtime.emit('join_call', {'callId': callId});
      
      // Emit call end event
      _realtime.emit('call_end', {
        'callId': callId,
        'userId': _currentUserId,
      });
      print('🔴 [END_CALL] Call end event emitted');

      await _cleanup();
      _resetCallState();
      Log.i('Call ended: $callId', 'WEBRTC_CALL_SERVICE');
      print('🔴 [END_CALL] Call ended successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ [END_CALL] Error ending call: $e');
      print('❌ [END_CALL] Stack trace: $stackTrace');
      Log.e('Error ending call', 'WEBRTC_CALL_SERVICE', e);
      await _cleanup();
      return false;
    }
  }

  /// Send WebRTC signaling message
  Future<void> sendWebRTCSignal(String type, Map<String, dynamic> signalData, {String? callId, String? targetUserId}) async {
    try {
      final targetCallId = callId ?? _currentCallId;
      if (targetCallId == null || !_realtime.isConnected) {
        print('❌ Cannot send WebRTC signal: callId=$targetCallId, connected=${_realtime.isConnected}');
        return;
      }

      final payload = {
        'callId': targetCallId,
        'userId': _currentUserId,
        if (targetUserId != null) 'targetUserId': targetUserId, // Always include targetUserId if provided
        ...signalData,
      };

      print('🔵 [SEND_SIGNAL] Sending WebRTC signal: type=$type, callId=$targetCallId, targetUserId=$targetUserId');
      print('🔵 [SEND_SIGNAL] Payload keys: ${payload.keys.join(", ")}');
      print('🔵 [SEND_SIGNAL] Current user ID: $_currentUserId');
      print('🔵 [SEND_SIGNAL] Realtime connected: ${_realtime.isConnected}');
      try {
        _realtime.emit('webrtc_$type', payload);
        print('🔵 [SEND_SIGNAL] ✅ WebRTC signal emitted successfully');
      } catch (e) {
        print('❌ [SEND_SIGNAL] ERROR emitting signal: $e');
        rethrow;
      }
      print('🔵 [SEND_SIGNAL] WebRTC signal sent successfully');
    } catch (e) {
      print('❌ Error sending WebRTC signal: $e');
      Log.e('Error sending WebRTC signal', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Toggle mute/unmute audio
  Future<void> toggleMute() async {
    try {
      if (_localStream == null) return;
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = !track.enabled;
      }
      Log.i('Audio ${audioTracks.first.enabled ? "unmuted" : "muted"}', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error toggling mute', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      if (_localStream == null) return;
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = !track.enabled;
      }
      Log.i('Video ${videoTracks.first.enabled ? "enabled" : "disabled"}', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error toggling video', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      if (_localStream == null) return;
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        await Helper.switchCamera(track);
      }
      Log.i('Camera switched', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error switching camera', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Toggle speaker/earpiece
  Future<bool> toggleSpeaker() async {
    try {
      if (kIsWeb) {
        // Web doesn't support speaker toggle
        Log.w('Speaker toggle not supported on web', 'WEBRTC_CALL_SERVICE');
        return false;
      }
      
      // Toggle speaker state
      _isSpeakerOn = !_isSpeakerOn;
      
      // Set speaker state
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      
      print('🔵 Speaker ${_isSpeakerOn ? "ON" : "OFF"}');
      Log.i('Speaker ${_isSpeakerOn ? "enabled" : "disabled"}', 'WEBRTC_CALL_SERVICE');
      
      return _isSpeakerOn;
    } catch (e) {
      print('❌ Error toggling speaker: $e');
      Log.e('Error toggling speaker', 'WEBRTC_CALL_SERVICE', e);
      // Revert state on error
      _isSpeakerOn = !_isSpeakerOn;
      return false;
    }
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    try {
      // Cancel all reconnection timers
      for (final timer in _reconnectionTimers.values) {
        timer?.cancel();
      }
      _reconnectionTimers.clear();
      _reconnectionAttempts.clear();
      
      // Close all peer connections
      for (final entry in _peerConnections.entries) {
        await entry.value.close();
      }
      _peerConnections.clear();

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;

      // Clear remote streams
      _remoteStreams.clear();
    } catch (e) {
      Log.e('Error cleaning up WebRTC resources', 'WEBRTC_CALL_SERVICE', e);
    }
  }

  /// Reset call state
  void _resetCallState() {
    print('🔵 [RESET] Resetting call state');
    
    // Save call history before resetting
    _saveCallHistory();
    
    _currentCallId = null;
    _currentCallType = null;
    _isInCall = false;
    _callStartTime = null;
    _callAnswerTime = null;
    _currentChatId = null;
    _currentChatName = null;
    _currentParticipantIds = null;
    _currentIsGroupChat = false;
    
    // NOTE: Do NOT clear callbacks here - they are set by the call screen
    // and should remain active until the screen is disposed
    // Clearing them here causes issues where callbacks are null when events arrive
    // The callbacks will be cleared in dispose() method
    
    print('🔵 [RESET] Call state reset complete');
  }
  
  /// Save call history when call ends
  Future<void> _saveCallHistory() async {
    if (_currentCallId == null || _currentUserId == null || _callStartTime == null) {
      return; // No call to save
    }
    
    try {
      final now = DateTime.now();
      final duration = _callAnswerTime != null
          ? now.difference(_callAnswerTime!).inSeconds
          : 0;
      
      // Determine call status
      String status = 'completed';
      if (_callAnswerTime == null) {
        status = 'missed'; // Call was never answered
      }
      
      // Determine direction (outgoing for caller, incoming for receiver)
      final direction = 'outgoing'; // This will be set by the caller
      
      await _callHistory.saveCallHistory(
        callId: _currentCallId!,
        chatId: _currentChatId ?? '',
        chatName: _currentChatName ?? 'Unknown',
        callerId: _currentUserId!,
        participantIds: _currentParticipantIds ?? [],
        callType: _currentCallType == CallType.video ? 'video' : 'voice',
        direction: direction,
        status: status,
        startedAt: _callStartTime!,
        answeredAt: _callAnswerTime,
        endedAt: now,
        duration: duration,
        isGroupChat: _currentIsGroupChat,
      );
      
      Log.i('Call history saved: $_currentCallId', 'WEBRTC_CALL_SERVICE');
    } catch (e) {
      Log.e('Error saving call history', 'WEBRTC_CALL_SERVICE', e);
    }
  }
  
  /// Mark call as answered (for history tracking)
  void markCallAnswered() {
    if (_callAnswerTime == null) {
      _callAnswerTime = DateTime.now();
      Log.i('Call marked as answered at $_callAnswerTime', 'WEBRTC_CALL_SERVICE');
    }
  }
  
  /// Track incoming call start time
  void trackIncomingCall(String callId, String chatId, String chatName, List<String> participantIds, bool isGroupChat) {
    _callStartTime = DateTime.now();
    _currentChatId = chatId;
    _currentChatName = chatName;
    _currentParticipantIds = participantIds;
    _currentIsGroupChat = isGroupChat;
  }

  /// Attempt to reconnect a peer connection after disconnection
  Future<void> _attemptReconnection(String userId, RTCPeerConnection peerConnection) async {
    // Check if we've exceeded max attempts
    final attempts = _reconnectionAttempts[userId] ?? 0;
    if (attempts >= _maxReconnectionAttempts) {
      print('❌ [RECONNECT] Max reconnection attempts reached for $userId');
      Log.w('Max reconnection attempts reached for $userId', 'WEBRTC_CALL_SERVICE');
      _remoteStreams.remove(userId);
      return;
    }
    
    // Cancel any existing timer
    _reconnectionTimers[userId]?.cancel();
    
    // Increment attempt count
    _reconnectionAttempts[userId] = attempts + 1;
    print('🔵 [RECONNECT] Attempting reconnection ${_reconnectionAttempts[userId]}/$_maxReconnectionAttempts for $userId');
    Log.i('Attempting reconnection ${_reconnectionAttempts[userId]}/$_maxReconnectionAttempts for $userId', 'WEBRTC_CALL_SERVICE');
    
    // Schedule reconnection attempt
    _reconnectionTimers[userId] = Timer(_reconnectionDelay, () async {
      try {
        // Check if call is still active
        if (_currentCallId == null || !_isInCall) {
          print('🔵 [RECONNECT] Call no longer active, cancelling reconnection');
          return;
        }
        
        // Check if peer connection still exists
        if (!_peerConnections.containsKey(userId) || _peerConnections[userId] != peerConnection) {
          print('🔵 [RECONNECT] Peer connection changed, cancelling reconnection');
          return;
        }
        
        // Check current connection state
        final connectionState = peerConnection.connectionState;
        final iceState = peerConnection.iceConnectionState;
        
        print('🔵 [RECONNECT] Current connection state: $connectionState, ICE state: $iceState');
        
        // If already connected, no need to reconnect
        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
            iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          print('🔵 [RECONNECT] Already connected, cancelling reconnection');
          _reconnectionAttempts.remove(userId);
          return;
        }
        
        // If connection is closed, we can't reconnect - need to create new peer connection
        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
            iceState == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          print('🔵 [RECONNECT] Connection closed, cannot reconnect - would need new peer connection');
          _remoteStreams.remove(userId);
          return;
        }
        
        // Try to restore connection by re-negotiating
        print('🔵 [RECONNECT] Attempting to restore connection by re-negotiating...');
        
        // Ensure local stream tracks are still added
        if (_localStream != null) {
          final senders = await peerConnection.getSenders();
          final hasAudio = senders.any((s) => s.track?.kind == 'audio');
          final hasVideo = senders.any((s) => s.track?.kind == 'video');
          
          print('🔵 [RECONNECT] Current senders - Audio: $hasAudio, Video: $hasVideo');
          
          // Re-add tracks if missing
          if (!hasAudio || !hasVideo) {
            print('🔵 [RECONNECT] Re-adding local stream tracks...');
            _localStream!.getTracks().forEach((track) {
              final hasTrack = senders.any((s) => s.track?.id == track.id);
              if (!hasTrack) {
                print('🔵 [RECONNECT] Re-adding track: ${track.kind}');
                peerConnection.addTrack(track, _localStream!);
              }
            });
          }
        }
        
        // Create new offer to re-negotiate
        print('🔵 [RECONNECT] Creating new offer for re-negotiation...');
        final offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        
        // Send the offer via signaling
        await sendWebRTCSignal('offer', {
          'offer': {
            'sdp': offer.sdp,
            'type': offer.type,
          },
        }, targetUserId: userId);
        
        print('🔵 [RECONNECT] ✅ Re-negotiation offer sent');
        Log.i('Re-negotiation offer sent for $userId', 'WEBRTC_CALL_SERVICE');
        
      } catch (e) {
        print('❌ [RECONNECT] Error during reconnection attempt: $e');
        Log.e('Error during reconnection attempt', 'WEBRTC_CALL_SERVICE', e);
        
        // Schedule next attempt if not at max
        if ((_reconnectionAttempts[userId] ?? 0) < _maxReconnectionAttempts) {
          _attemptReconnection(userId, peerConnection);
        } else {
          _remoteStreams.remove(userId);
        }
      }
    });
  }

  /// Get current call ID
  String? get currentCallId => _currentCallId;

  /// Get current call type
  CallType? get currentCallType => _currentCallType;
  
  /// Get peer connection for a user (for quality monitoring)
  RTCPeerConnection? getPeerConnection(String userId) {
    return _peerConnections[userId];
  }
  
  /// Get all peer connections (for group calls)
  Map<String, RTCPeerConnection> get peerConnections => Map.unmodifiable(_peerConnections);

  /// Check if in call
  bool get isInCall => _isInCall;

  /// Get local stream
  MediaStream? get localStream => _localStream;

  /// Get remote streams
  Map<String, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);

  /// Cleanup
  void dispose() {
    print('🔵 [DISPOSE] Disposing WebRTC Call Service');
    _cleanup();
    _resetCallState();
    
    // Clear callbacks on dispose (screen is closing)
    onCallAccepted = null;
    onCallRejected = null;
    onCallEnded = null;
    onCallError = null;
    onIncomingCall = null;
    onLocalStream = null;
    onRemoteStream = null;
    
    print('🔵 [DISPOSE] WebRTC Call Service disposed');
  }
}
