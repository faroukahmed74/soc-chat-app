// =============================================================================
// RESPONSIVE DESIGN TEST SCREEN
// =============================================================================
// This screen tests responsive design across different screen sizes
// and platforms (Android, iOS, Web) to ensure proper scaling and layout.

import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class ResponsiveTestScreen extends StatelessWidget {
  const ResponsiveTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsive Design Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Type Indicator
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen Type: ${screenType.name.toUpperCase()}',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Width: ${MediaQuery.of(context).size.width.toStringAsFixed(0)}px',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Height: ${MediaQuery.of(context).size.height.toStringAsFixed(0)}px',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Platform: ${Theme.of(context).platform.name.toUpperCase()}',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            
            // Responsive Text Test
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responsive Text Test',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    Text(
                      'This is heading text that scales with screen size',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                    Text(
                      'This is body text that adapts to different screen sizes for optimal readability.',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                    Text(
                      'This is caption text for additional information.',
                      style: ResponsiveUtils.getResponsiveCaptionStyle(context),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            
            // Responsive Avatar Test
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responsive Avatar Test',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: ResponsiveUtils.getResponsiveAvatarRadius(context),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.person,
                            size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Name',
                                style: ResponsiveUtils.getResponsiveBodyStyle(context),
                              ),
                              Text(
                                'user@example.com',
                                style: ResponsiveUtils.getResponsiveCaptionStyle(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            
            // Responsive Button Test
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responsive Button Test',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveUtils.getResponsiveButtonHeight(context),
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.add, size: ResponsiveUtils.getResponsiveIconSize(context)),
                        label: Text(
                          'Primary Action',
                          style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0)),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveUtils.getResponsiveButtonHeight(context),
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.edit, size: ResponsiveUtils.getResponsiveIconSize(context)),
                              label: Text(
                                'Edit',
                                style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14.0)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveUtils.getResponsiveButtonHeight(context),
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.delete, size: ResponsiveUtils.getResponsiveIconSize(context)),
                              label: Text(
                                'Delete',
                                style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14.0)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            
            // Responsive Layout Test
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responsive Layout Test',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Wide screen: side-by-side layout
                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Left Panel',
                                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                              Expanded(
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Right Panel',
                                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Narrow screen: stacked layout
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Center(
                                  child: Text(
                                    'Top Panel',
                                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                                  ),
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                              Container(
                                width: double.infinity,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Center(
                                  child: Text(
                                    'Bottom Panel',
                                    style: ResponsiveUtils.getResponsiveBodyStyle(context),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            
            // Platform-specific Test
            Card(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform-Specific Test',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    Text(
                      'Is Web: ${ResponsiveUtils.isWeb}',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Is Mobile Platform: ${ResponsiveUtils.isMobilePlatform}',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Is Mobile Screen: $isMobile',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Is Tablet Screen: $isTablet',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                    Text(
                      'Is Desktop Screen: $isDesktop',
                      style: ResponsiveUtils.getResponsiveBodyStyle(context),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
          ],
        ),
      ),
    );
  }
}
