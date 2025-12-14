// =============================================================================
// CHAT HEADER WIDGET
// =============================================================================
// A modern chat header with platform-specific styling and functionality

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String chatName;
  final bool isGroupChat;
  final VoidCallback onBack;
  final VoidCallback? onInfo;
  final VoidCallback? onSearch;
  final VoidCallback? onCall;
  final VoidCallback? onVideoCall;
  final List<String>? onlineMembers;

  const ChatHeader({
    Key? key,
    required this.chatName,
    required this.isGroupChat,
    required this.onBack,
    this.onInfo,
    this.onSearch,
    this.onCall,
    this.onVideoCall,
    this.onlineMembers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 24 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: Icon(
                  isWeb ? Icons.arrow_back : Icons.arrow_back_ios,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                tooltip: 'Back',
              ),

              // Chat info section
              Expanded(
                child: GestureDetector(
                  onTap: onInfo,
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                        child: Text(
                          chatName.isNotEmpty ? chatName[0].toUpperCase() : 'C',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Chat name and status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chatName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isGroupChat && onlineMembers != null)
                              Text(
                                '${onlineMembers!.length} members online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              )
                            else if (!isGroupChat)
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Row(
                children: [
                  if (onSearch != null)
                    IconButton(
                      onPressed: onSearch,
                      icon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      tooltip: 'Search',
                    ),

                  // Voice and video call buttons removed

                  if (onInfo != null)
                    IconButton(
                      onPressed: onInfo,
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      tooltip: 'More options',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);
}
