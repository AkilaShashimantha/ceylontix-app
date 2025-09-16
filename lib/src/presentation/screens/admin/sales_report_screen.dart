import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({Key? key}) : super(key: key);

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<Map<String, dynamic>> _getSalesData(Event event) async {
    try {
      // Get all bookings for this event
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: event.id)
          .where('status', isEqualTo: 'confirmed')
          .get();

      // Group by tier and calculate totals
      Map<String, Map<String, dynamic>> tierSales = {};
      double totalRevenue = 0;
      int totalTicketsSold = 0;

      for (var booking in bookingsQuery.docs) {
        final data = booking.data();
        final tierName = data['tierName'] as String;
        final quantity = data['quantity'] as int;
        final totalPrice = (data['totalPrice'] as num).toDouble();

        if (!tierSales.containsKey(tierName)) {
          tierSales[tierName] = {
            'ticketsSold': 0,
            'revenue': 0.0,
            'price': totalPrice / quantity, // Calculate unit price
          };
        }

        tierSales[tierName]!['ticketsSold'] += quantity;
        tierSales[tierName]!['revenue'] += totalPrice;
        totalTicketsSold += quantity;
        totalRevenue += totalPrice;
      }

      return {
        'tierSales': tierSales,
        'totalRevenue': totalRevenue,
        'totalTicketsSold': totalTicketsSold,
      };
    } catch (e) {
      print('Error fetching sales data: $e');
      return {
        'tierSales': <String, Map<String, dynamic>>{},
        'totalRevenue': 0.0,
        'totalTicketsSold': 0,
      };
    }
  }

  Widget _buildSalesCard(Event event, Map<String, dynamic> salesData) {
    final tierSales = salesData['tierSales'] as Map<String, Map<String, dynamic>>;
    final totalRevenue = salesData['totalRevenue'] as double;
    final totalTicketsSold = salesData['totalTicketsSold'] as int;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: () => _generatePDFReport(event, salesData),
                  tooltip: 'Download PDF Report',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat.yMMMd().add_jm().format(event.date)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Venue: ${event.venue}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Divider(height: 20),
            
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        totalTicketsSold.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text('Tickets Sold'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'LKR ${totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text('Total Revenue'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Sales by Ticket Tier:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Tier breakdown
            if (tierSales.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No tickets sold yet',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...tierSales.entries.map((entry) {
                final tierName = entry.key;
                final tierData = entry.value;
                final ticketsSold = tierData['ticketsSold'] as int;
                final revenue = tierData['revenue'] as double;
                final unitPrice = tierData['price'] as double;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(tierName),
                    subtitle: Text('Unit Price: LKR ${unitPrice.toStringAsFixed(2)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$ticketsSold tickets',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'LKR ${revenue.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDFReport(Event event, Map<String, dynamic> salesData) async {
    try {
      final pdf = pw.Document();
      final tierSales = salesData['tierSales'] as Map<String, Map<String, dynamic>>;
      final totalRevenue = salesData['totalRevenue'] as double;
      final totalTicketsSold = salesData['totalTicketsSold'] as int;

      // Load logo
      Uint8List? logoBytes;
      try {
        logoBytes = (await rootBundle.load('assets/logo/app_logo.png')).buffer.asUint8List();
      } catch (e) {
        print('Could not load logo: $e');
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header with logo and title
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoBytes != null)
                      pw.Image(
                        pw.MemoryImage(logoBytes),
                        height: 60,
                        width: 60,
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'CEYLONTIX',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Ticket Sales Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.Divider(thickness: 2),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Event Information
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Event Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Event Name: ${event.name}'),
                    pw.Text('Date: ${DateFormat.yMMMd().add_jm().format(event.date)}'),
                    pw.Text('Venue: ${event.venue}'),
                    pw.Text('Report Generated: ${DateFormat.yMMMd().add_jm().format(DateTime.now())}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Sales Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          totalTicketsSold.toString(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                        pw.Text('Total Tickets Sold'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'LKR ${totalRevenue.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text('Total Revenue'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Tier Breakdown
              if (tierSales.isNotEmpty) ...[
                pw.Text(
                  'Sales Breakdown by Ticket Tier',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Tier Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Unit Price (LKR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Tickets Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Revenue (LKR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...tierSales.entries.map((entry) {
                      final tierName = entry.key;
                      final tierData = entry.value;
                      final ticketsSold = tierData['ticketsSold'] as int;
                      final revenue = tierData['revenue'] as double;
                      final unitPrice = tierData['price'] as double;

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(tierName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(unitPrice.toStringAsFixed(2)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(ticketsSold.toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(revenue.toStringAsFixed(2)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ] else ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Text(
                    'No tickets sold for this event yet.',
                    style: const pw.TextStyle(color: PdfColors.grey),
                  ),
                ),
              ],

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Generated by CeylonTix Admin Panel',
                  style: const pw.TextStyle(color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      // Save and share PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'CeylonTix_Sales_Report_${event.name.replaceAll(' ', '_')}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _startDate != null && _endDate != null ? Colors.yellow : Colors.white,
            ),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date Range',
          ),
          if (_startDate != null && _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: _clearDateFilter,
              tooltip: 'Clear Date Filter',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isDesktop ? 80 : 70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Center(
              child: SizedBox(
                width: width * 0.5, // Half of screen width
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search events by name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: _eventRepository.getEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No events found.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final events = snapshot.data!;
          
          // Filter events based on search query and date range
          var filteredEvents = _searchQuery.isEmpty
              ? events
              : events.where((event) => 
                  event.name.toLowerCase().contains(_searchQuery)).toList();

          // Apply date filtering
          if (_startDate != null && _endDate != null) {
            filteredEvents = filteredEvents.where((event) {
              final eventDate = event.date;
              return eventDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                     eventDate.isBefore(_endDate!.add(const Duration(days: 1)));
            }).toList();
          }

          if (filteredEvents.isEmpty) {
            return const Center(
              child: Text(
                'No events match your search.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredEvents.length,
            itemBuilder: (context, index) {
              final event = filteredEvents[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _getSalesData(event),
                builder: (context, salesSnapshot) {
                  if (salesSnapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Container(
                        height: 100,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (salesSnapshot.hasError) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Container(
                        height: 100,
                        child: Center(
                          child: Text('Error loading data: ${salesSnapshot.error}'),
                        ),
                      ),
                    );
                  }

                  return _buildSalesCard(event, salesSnapshot.data!);
                },
              );
            },
          );
        },
      ),
    );
  }
}
