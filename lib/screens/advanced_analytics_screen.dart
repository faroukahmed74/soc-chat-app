// =============================================================================
// ADVANCED ANALYTICS SCREEN
// =============================================================================
// This screen provides advanced analytics with charts, trends, and detailed metrics
// including user growth, message trends, engagement metrics, retention rates, and peak usage

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final ThemeService _themeService = ThemeService();
  
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = false;
  int _selectedPeriod = 30; // days
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }
  
  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final data = await _adminService.getAdvancedAnalytics(
        startDate: _startDate,
        endDate: _endDate,
        period: _selectedPeriod,
      );
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading advanced analytics', 'ADVANCED_ANALYTICS', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null
              ? Center(
                  child: Padding(
                    padding: padding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 48.0,
                            tablet: 56.0,
                            desktop: 64.0,
                          ),
                          color: Colors.grey,
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                        Text(
                          'No analytics data available',
                          style: ResponsiveUtils.getResponsiveBodyStyle(context),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                        SizedBox(
                          width: isMobile ? double.infinity : null,
                          child: ElevatedButton(
                            onPressed: _loadAnalytics,
                            child: const Text('Load Analytics'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: double.infinity,
                      tablet: 800.0,
                      desktop: 1200.0,
                    );
                    
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: SingleChildScrollView(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPeriodSelector(),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                              _buildEngagementMetrics(),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                              _buildUserGrowthChart(),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                              _buildMessageTrendsChart(),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                              _buildPeakUsageChart(),
                              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                              if (!isMobile) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildTopUsersList()),
                                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                                    Expanded(child: _buildTopChatsList()),
                                  ],
                                ),
                              ] else ...[
                                _buildTopUsersList(),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                                _buildTopChatsList(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
  
  Widget _buildPeriodSelector() {
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 6.0,
                tablet: 8.0,
                desktop: 12.0,
              ),
              runSpacing: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 6.0,
                tablet: 8.0,
                desktop: 12.0,
              ),
              children: [
                _buildPeriodChip('7 Days', 7),
                _buildPeriodChip('30 Days', 30),
                _buildPeriodChip('90 Days', 90),
                _buildPeriodChip('Custom', -1),
              ],
            ),
            if (_selectedPeriod == -1) ...[
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              isMobile
                  ? Column(
                      children: [
                        ListTile(
                          title: const Text('Start Date'),
                          subtitle: Text(
                            _startDate != null
                                ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                : 'Select start date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                              _loadAnalytics();
                            }
                          },
                        ),
                        ListTile(
                          title: const Text('End Date'),
                          subtitle: Text(
                            _endDate != null
                                ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                : 'Select end date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                              _loadAnalytics();
                            }
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Start Date'),
                            subtitle: Text(
                              _startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                  : 'Select start date',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _startDate = date);
                                _loadAnalytics();
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('End Date'),
                            subtitle: Text(
                              _endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                  : 'Select end date',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: _startDate ?? DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _endDate = date);
                                _loadAnalytics();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildEngagementMetrics() {
    final engagement = _analyticsData!['engagement'] as Map<String, dynamic>? ?? {};
    final userGrowth = _analyticsData!['userGrowth'] as Map<String, dynamic>? ?? {};
    final messageTrends = _analyticsData!['messageTrends'] as Map<String, dynamic>? ?? {};
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Metrics',
              style: ResponsiveUtils.getResponsiveHeadingStyle(context),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            if (isMobile) ...[
              _buildMetricCard(
                'DAU',
                '${engagement['dau'] ?? 0}',
                'Daily Active Users',
                Icons.people,
                Colors.blue,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildMetricCard(
                'MAU',
                '${engagement['mau'] ?? 0}',
                'Monthly Active Users',
                Icons.group,
                Colors.green,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildMetricCard(
                'Retention',
                '${engagement['retentionRate'] ?? '0'}%',
                'User Retention Rate',
                Icons.trending_up,
                Colors.purple,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildMetricCard(
                'Avg Messages',
                '${engagement['avgMessagesPerUser'] ?? '0'}',
                'Per User',
                Icons.message,
                Colors.orange,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildMetricCard(
                'User Growth',
                '${userGrowth['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                'Growth Rate',
                Icons.trending_up,
                Colors.teal,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildMetricCard(
                'Message Growth',
                '${messageTrends['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                'Growth Rate',
                Icons.trending_up,
                Colors.red,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'DAU',
                      '${engagement['dau'] ?? 0}',
                      'Daily Active Users',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                  Expanded(
                    child: _buildMetricCard(
                      'MAU',
                      '${engagement['mau'] ?? 0}',
                      'Monthly Active Users',
                      Icons.group,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Retention',
                      '${engagement['retentionRate'] ?? '0'}%',
                      'User Retention Rate',
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                  Expanded(
                    child: _buildMetricCard(
                      'Avg Messages',
                      '${engagement['avgMessagesPerUser'] ?? '0'}',
                      'Per User',
                      Icons.message,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'User Growth',
                      '${userGrowth['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                      'Growth Rate',
                      Icons.trending_up,
                      Colors.teal,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                  Expanded(
                    child: _buildMetricCard(
                      'Message Growth',
                      '${messageTrends['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                      'Growth Rate',
                      Icons.trending_up,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
        context,
        mobile: 12.0,
        tablet: 14.0,
        desktop: 16.0,
      )),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: ResponsiveUtils.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
              Expanded(
                child: Text(
                  title,
                  style: ResponsiveUtils.getResponsiveCaptionStyle(
                    context,
                    color: Colors.grey[600],
                  )?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 28.0,
              ),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: ResponsiveUtils.getResponsiveCaptionStyle(
              context,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserGrowthChart() {
    final userGrowth = _analyticsData!['userGrowth'] as Map<String, dynamic>? ?? {};
    final data = userGrowth['data'] as List<dynamic>? ?? [];
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Growth Over Time',
              style: ResponsiveUtils.getResponsiveHeadingStyle(context),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 200.0,
                tablet: 250.0,
                desktop: 300.0,
              ),
              child: LineChart(
                      subtitle: Text(
                        _startDate != null
                            ? DateFormat('yyyy-MM-dd').format(_startDate!)
                            : 'Select start date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                          _loadAnalytics();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        _endDate != null
                            ? DateFormat('yyyy-MM-dd').format(_endDate!)
                            : 'Select end date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                          _loadAnalytics();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPeriodChip(String label, int period) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = period;
            if (period != -1) {
              _startDate = null;
              _endDate = null;
            }
          });
          _loadAnalytics();
        }
      },
    );
  }
  
  Widget _buildEngagementMetrics() {
    final engagement = _analyticsData!['engagement'] as Map<String, dynamic>? ?? {};
    final userGrowth = _analyticsData!['userGrowth'] as Map<String, dynamic>? ?? {};
    final messageTrends = _analyticsData!['messageTrends'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Engagement Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'DAU',
                    '${engagement['dau'] ?? 0}',
                    'Daily Active Users',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'MAU',
                    '${engagement['mau'] ?? 0}',
                    'Monthly Active Users',
                    Icons.group,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Retention',
                    '${engagement['retentionRate'] ?? '0'}%',
                    'User Retention Rate',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Avg Messages',
                    '${engagement['avgMessagesPerUser'] ?? '0'}',
                    'Per User',
                    Icons.message,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'User Growth',
                    '${userGrowth['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                    'Growth Rate',
                    Icons.trending_up,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Message Growth',
                    '${messageTrends['growthRate']?.toStringAsFixed(1) ?? '0'}%',
                    'Growth Rate',
                    Icons.trending_up,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserGrowthChart() {
    final userGrowth = _analyticsData!['userGrowth'] as Map<String, dynamic>? ?? {};
    final data = userGrowth['data'] as List<dynamic>? ?? [];
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Growth Over Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= data.length) return const Text('');
                          final dateStr = data[value.toInt()]['date'] as String? ?? '';
                          if (dateStr.isEmpty) return const Text('');
                          try {
                            final date = DateTime.parse(dateStr);
                            return Text(
                              DateFormat('MMM dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          } catch (e) {
                            return const Text('');
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        data.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          (data[index]['count'] as num? ?? 0).toDouble(),
                        ),
                      ),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageTrendsChart() {
    final messageTrends = _analyticsData!['messageTrends'] as Map<String, dynamic>? ?? {};
    final data = messageTrends['data'] as List<dynamic>? ?? [];
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message Trends Over Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= data.length) return const Text('');
                          final dateStr = data[value.toInt()]['date'] as String? ?? '';
                          if (dateStr.isEmpty) return const Text('');
                          try {
                            final date = DateTime.parse(dateStr);
                            return Text(
                              DateFormat('MMM dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          } catch (e) {
                            return const Text('');
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        data.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          (data[index]['count'] as num? ?? 0).toDouble(),
                        ),
                      ),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPeakUsageChart() {
    final peakUsage = _analyticsData!['peakUsage'] as Map<String, dynamic>? ?? {};
    final byHour = peakUsage['byHour'] as List<dynamic>? ?? [];
    
    if (byHour.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Peak Usage by Hour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          return Text(
                            '$hour:00',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: byHour.map((item) {
                    final hour = item['hour'] as int? ?? 0;
                    final count = (item['count'] as num? ?? 0).toDouble();
                    return BarChartGroupData(
                      x: hour,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: Colors.purple,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopUsersList() {
    final topUsers = _analyticsData!['topUsers'] as List<dynamic>? ?? [];
    
    if (topUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Active Users',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topUsers.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text('${index + 1}'),
                ),
                title: Text(user['userName'] as String? ?? 'Unknown'),
                subtitle: Text('${user['messageCount'] ?? 0} messages'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopChatsList() {
    final topChats = _analyticsData!['topChats'] as List<dynamic>? ?? [];
    
    if (topChats.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Active Chats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topChats.asMap().entries.map((entry) {
              final index = entry.key;
              final chat = entry.value as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text('${index + 1}'),
                ),
                title: Text(chat['chatName'] as String? ?? 'Unknown Chat'),
                subtitle: Text('${chat['messageCount'] ?? 0} messages'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              );
            }),
          ],
        ),
      ),
    );
  }
}

