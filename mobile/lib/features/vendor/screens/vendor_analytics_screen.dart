import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../widgets/vendor_shared.dart';

class VendorAnalyticsScreen extends ConsumerStatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  ConsumerState<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends ConsumerState<VendorAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intel = ref.watch(vendorIntelligenceProvider);

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Business Intelligence (BI) Center', style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EosColors.champagne,
          labelColor: EosColors.champagne,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Marketplace Metrics'),
            Tab(text: 'Operational Efficiency'),
            Tab(text: 'Forecast & Seasonality'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketplaceMetricsTab(intel),
          _buildOperationalTab(intel),
          _buildForecastTab(),
        ],
      ),
    );
  }

  Widget _buildMarketplaceMetricsTab(IntelligenceState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard('Marketplace Views', '1,420 views', '+14.2%'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard('Quote Conversion Rate', '84.2%', '+2.1%'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard('Customer Retention', '96.4%', '+0.5%'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard('Negotiation Win Rate', '72.3%', '+4.8%'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white.withOpacity(0.02),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOP PERFORMING PACKAGES', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildInsightRow('1. Luxury Wedding Catering Package', '12 bookings (₦14.4M)'),
                _buildInsightRow('2. Deluxe Buffet setup', '8 bookings (₦6.8M)'),
                _buildInsightRow('3. DJ Rig & Lights', '5 bookings (₦3.2M)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String growth) {
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(growth, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOperationalTab(IntelligenceState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESPONSE TIME & SATISFACTION INDEX', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Average quote response time: 24 minutes', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 4),
                Text('SLA compliance rate: ${state.slaCompliance}%', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text('Refund rate: 0.2% (Low)', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text('Cancellation rate: 1.1%', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI REVENUE FORECAST & SEASONALITY (ANALYTICS360)', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('July Revenue Forecast: ₦4,250,000.00', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Peak Seasonality heat trend: December (High booking probability)', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 4),
                Text('Optimal booking day trend: Saturdays (Weekend peak demand up 24%)', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MONTHLY REVENUE TRENDS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const TrendLineChart(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Jan', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Feb', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Mar', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Apr', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('May', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Jun', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Jul', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Aug', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Sep', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Oct', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Nov', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    Text('Dec', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendLinePainter(),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.25, size.height * 0.85,
      size.width * 0.5, size.height * 0.3,
      size.width * 0.75, size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.7,
      size.width * 0.95, size.height * 0.15,
      size.width, size.height * 0.2,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFF59E0B).withOpacity(0.15), Colors.transparent],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
