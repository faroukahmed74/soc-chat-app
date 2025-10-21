// =============================================================================
// TYPING INDICATOR WIDGET
// =============================================================================
// An animated typing indicator for real-time chat feedback

import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final String? userName;
  final Animation<double> animation;

  const TypingIndicator({
    Key? key,
    this.userName,
    required this.animation,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _dotController,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.6,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _dotController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            child: Text(
              widget.userName?.isNotEmpty == true 
                  ? widget.userName![0].toUpperCase() 
                  : 'U',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName?.isNotEmpty == true 
                      ? '${widget.userName} is typing'
                      : 'Someone is typing',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _dotController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        return Container(
                          margin: EdgeInsets.only(
                            right: index < 2 ? 4 : 0,
                          ),
                          child: Transform.scale(
                            scale: _dotAnimations[index].value,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
