import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Wrapper widget to ensure all screens are responsive
/// Use this as a base for all screens to ensure consistent responsive behavior
class ResponsiveScreenWrapper extends StatelessWidget {
  final Widget child;
  final bool enableScrolling;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const ResponsiveScreenWrapper({
    super.key,
    required this.child,
    this.enableScrolling = true,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Get responsive padding
    final responsivePadding = padding ?? ResponsiveUtils.getResponsivePadding(context);

    // Get max width for content centering on larger screens
    final maxWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: double.infinity,
      tablet: 768.0,
      desktop: 1200.0,
    );

    Widget content = child;

    // Wrap in constrained box for larger screens
    if (isTablet || isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    // Add padding
    content = Padding(
      padding: responsivePadding,
      child: content,
    );

    // Enable scrolling if needed
    if (enableScrolling) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    // Add background color if provided
    if (backgroundColor != null) {
      content = Container(
        color: backgroundColor,
        child: content,
      );
    }

    return content;
  }
}

/// Responsive dialog wrapper for consistent dialog sizing
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool barrierDismissible;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);
    
    final dialogWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: screenWidth * 0.9,
      tablet: 500.0,
      desktop: 600.0,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: ResponsiveUtils.getResponsivePadding(context) * 0.75,
                child: isMobile
                    ? Column(
                        children: actions!.map((action) => SizedBox(
                          width: double.infinity,
                          child: action,
                        )).toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Responsive card wrapper for consistent card sizing
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? ResponsiveUtils.getResponsiveValue(
        context,
        mobile: 2.0,
        tablet: 4.0,
        desktop: 6.0,
      ),
      margin: margin ?? EdgeInsets.all(
        ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
      ),
      child: Padding(
        padding: padding ?? ResponsiveUtils.getResponsivePadding(context),
        child: child,
      ),
    );
  }
}

