// =============================================================================
// PERFORMANCE MONITORING SCREEN
// =============================================================================
// Comprehensive performance monitoring dashboard with metrics, charts, and alerts
// Features: API response times, error rates, resource usage, database performance

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class PerformanceMonitoringScreen extends StatefulWidget {
  const PerformanceMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<PerformanceMonitoringScreen> createState() => _PerformanceMonitoringScreenState();
}

class _PerformanceMonitoringScreenState extends State<PerformanceMonitoringScreen> {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late ThemeService _themeService;

  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = false;
  bool _isLoadingAlerts = false;
  String _selectedPeriod = '1h';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _loadMetrics();
    _loadAlerts();
    
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadMetrics();
      _loadAlerts();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final metrics = await _adminService.getPerformanceMetrics(period: _selectedPeriod);
      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading performance metrics', 'PERFORMANCE_MONITORING', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load metrics: $e')),
        );
      }
    }
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoadingAlerts = true);
    try {
      final data = await _adminService.getPerformanceAlerts();
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);
        _isLoadingAlerts = false;
      });
    } catch (e) {
      Log.e('Error loading performance alerts', 'PERFORMANCE_MONITORING', e);
      setState(() => _isLoadingAlerts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Monitoring'),
        actions: [
          // Period selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.timer),
            onSelected: (period) {
              setState(() {
                _selectedPeriod = period;
                _loadMetrics();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '15m', child: Text('Last 15 minutes')),
              const PopupMenuItem(value: '1h', child: Text('Last hour')),
              const PopupMenuItem(value: '24h', child: Text('Last 24 hours')),
              const PopupMenuItem(value: '7d', child: Text('Last 7 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _selectedPeriod.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadMetrics();
              _loadAlerts();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _metrics == null
              ? Center(
                  child: Text('Failed to load metrics', style: TextStyle(fontSize: fontSize)),
                )
              : SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Metrics Cards
                      _buildMetricsCards(context, isMobile, isTablet, padding, fontSize),
                      
                      const SizedBox(height: 16),
                      
                      // Response Times Chart
                      _buildResponseTimeChart(context, isMobile, isTablet, padding, fontSize),
                      
                      const SizedBox(height: 16),
                      
                      // Error Rates Chart
                      _buildErrorRateChart(context, isMobile, isTablet, padding, fontSize),
                      
                      const SizedBox(height: 16),
                      
                      // System Resources
                      _buildSystemResources(context, isMobile, isTablet, padding, fontSize),
                      
                      const SizedBox(height: 16),
                      
                      // Database Performance
                      _buildDatabasePerformance(context, isMobile, isTablet, padding, fontSize),
                      
                      const SizedBox(height: 16),
                      
                      // Alerts
                      _buildAlertsSection(context, isMobile, isTablet, padding, fontSize),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricsCards(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final current = _metrics?['current'] ?? {};
    final averages = _metrics?['averages'] ?? {};
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : isTablet ? 3 : 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Active Connections',
          current['activeConnections']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          'Avg Response Time',
          () {
            final responseTimes = averages['responseTimes'] as Map?;
            if (responseTimes == null || responseTimes.isEmpty) return '0ms';
            final values = responseTimes.values.toList();
            if (values.isEmpty) return '0ms';
            final first = values.first;
            if (first is Map) {
              return '${((first['avg'] ?? 0) as num).toStringAsFixed(0)}ms';
            }
            return '0ms';
          }(),
          Icons.speed,
          Colors.green,
        ),
        _buildMetricCard(
          'Error Rate',
          () {
            final errorRates = averages['errorRates'] as Map?;
            if (errorRates == null || errorRates.isEmpty) return '0.00%';
            final values = errorRates.values.toList();
            if (values.isEmpty) return '0.00%';
            final first = values.first;
            if (first is num) {
              return '${first.toStringAsFixed(2)}%';
            }
            return '0.00%';
          }(),
          Icons.error_outline,
          Colors.orange,
        ),
        _buildMetricCard(
          'Delivery Rate',
          '${(averages['messageDeliveryRate'] ?? 100).toStringAsFixed(1)}%',
          Icons.send,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTimeChart(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final historical = List<Map<String, dynamic>>.from(_metrics?['historical'] ?? []);
    if (historical.isEmpty) {
      return Card(
        child: Padding(
          padding: padding,
          child: Text('No response time data available', style: TextStyle(fontSize: fontSize)),
        ),
      );
    }

    final responseTimes = historical
        .map((m) {
          final responseTimesMap = m['responseTimes'] as Map?;
          if (responseTimesMap == null || responseTimesMap.isEmpty) return 0.0;
          final values = responseTimesMap.values.toList();
          if (values.isEmpty) return 0.0;
          final first = values.first;
          if (first is Map) {
            return ((first['avg'] ?? 0) as num).toDouble();
          }
          return 0.0;
        })
        .toList()
        .cast<double>();

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Response Times', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: responseTimes.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
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

  Widget _buildErrorRateChart(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final errorRates = _metrics?['averages']?['errorRates'] as Map? ?? {};
    if (errorRates.isEmpty) {
      return Card(
        child: Padding(
          padding: padding,
          child: Text('No error rate data available', style: TextStyle(fontSize: fontSize)),
        ),
      );
    }

    final entries = errorRates.entries.toList();
    final maxValue = entries.map((e) => (e.value as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Error Rates by Endpoint', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue > 0 ? maxValue * 1.2 : 10,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < entries.length) {
                            final endpoint = entries[value.toInt()].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                endpoint.length > 20 ? '${endpoint.substring(0, 20)}...' : endpoint,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  barGroups: entries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value.value as num).toDouble(),
                          color: Colors.red,
                          width: 16,
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

  Widget _buildSystemResources(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final resources = _metrics?['systemResources'] ?? {};
    final memory = resources['memory'] ?? {};
    final cpu = resources['cpu'] ?? {};
    final loadAvg = resources['loadAverage'] as List? ?? [];

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('System Resources', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildResourceCard(
                    'Memory Used',
                    '${((memory['heapUsed'] ?? 0) / 1024 / 1024).toStringAsFixed(0)} MB',
                    Icons.memory,
                    Colors.blue,
                    (memory['heapUsed'] ?? 0) / (memory['heapTotal'] ?? 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildResourceCard(
                    'CPU Usage',
                    '${((cpu['user'] ?? 0) / 1000000).toStringAsFixed(1)}%',
                    Icons.speed,
                    Colors.orange,
                    (cpu['user'] ?? 0) / 10000000,
                  ),
                ),
              ],
            ),
            if (loadAvg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Load Average: ${loadAvg.map((e) => e.toStringAsFixed(2)).join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(String title, String value, IconData icon, Color color, double percentage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabasePerformance(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final db = _metrics?['database'] ?? {};
    final performance = db['performance'] ?? {};
    final connectionPool = db['connectionPool'] ?? {};

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Database Performance', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (performance.isNotEmpty) ...[
              Text('Collections: ${performance['collections'] ?? 0}'),
              Text('Data Size: ${((performance['dataSize'] ?? 0) / 1024 / 1024).toStringAsFixed(2)} MB'),
              Text('Index Size: ${((performance['indexSize'] ?? 0) / 1024 / 1024).toStringAsFixed(2)} MB'),
            ],
            if (connectionPool.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Connections:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  Current: ${connectionPool['connections']?['current'] ?? 0}'),
              Text('  Available: ${connectionPool['connections']?['available'] ?? 0}'),
              Text('  Active: ${connectionPool['connections']?['active'] ?? 0}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingAlerts) {
      return const Card(child: Center(child: CircularProgressIndicator()));
    }

    if (_alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: padding,
          child: Text('No performance alerts', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Text('Performance Alerts', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _alerts.length,
            itemBuilder: (context, index) {
              final alert = _alerts[index];
              final severity = alert['severity'] ?? 'medium';
              Color severityColor = Colors.orange;
              if (severity == 'high') severityColor = Colors.red;
              if (severity == 'low') severityColor = Colors.yellow;
              
              return ListTile(
                leading: Icon(Icons.warning, color: severityColor),
                title: Text(alert['type'] ?? 'Unknown'),
                subtitle: Text(alert['message'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    try {
                      await _adminService.resolvePerformanceAlert(alert['id']);
                      _loadAlerts();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error resolving alert: $e')),
                        );
                      }
                    }
                  },
                  tooltip: 'Resolve',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

