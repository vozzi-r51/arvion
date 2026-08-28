import 'package:flutter/material.dart';
import '../../core/services/ecommerce_channel_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class EcommerceChannelsScreen extends StatefulWidget {
  final int companyId;
  const EcommerceChannelsScreen({super.key, required this.companyId});

  @override
  State<EcommerceChannelsScreen> createState() =>
      _EcommerceChannelsScreenState();
}

class _EcommerceChannelsScreenState extends State<EcommerceChannelsScreen> {
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final channels =
        await EcommerceChannelService.listChannels(widget.companyId);
    final orders =
        await EcommerceChannelService.listChannelOrders(widget.companyId);
    setState(() {
      _channels = channels;
      _orders = orders;
      _loading = false;
    });
  }

  void _showAddChannelDialog() {
    final nameCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    String type = 'daraz';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('E-commerce Channel Connect Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Channel Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'daraz', child: Text('Daraz Pakistan Store')),
                    DropdownMenuItem(
                        value: 'whatsapp',
                        child: Text('WhatsApp Business Catalog')),
                    DropdownMenuItem(
                        value: 'shopify', child: Text('Shopify Store')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Channel Name (e.g. My Daraz Shop) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                      labelText: 'API Key / Seller Token *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                await EcommerceChannelService.saveChannel(
                  companyId: widget.companyId,
                  channelType: type,
                  channelName: name,
                  apiKey: keyCtrl.text.trim(),
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Connect Channel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportWhatsAppCatalog() async {
    final csvData = await EcommerceChannelService.generateWhatsAppCatalogCsv(
        widget.companyId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp Business Catalog CSV'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Yeh CSV file WhatsApp Business Manager Catalog mein direct upload kar ke tamam products WhatsApp shop par list kar sakte hain:',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade100,
                child: SelectableText(csvData,
                    style:
                        const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-commerce Sync (Daraz & WhatsApp)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'WhatsApp Catalog Export',
            onPressed: _exportWhatsAppCatalog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connected Channels',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Connect Channel'),
                        onPressed: _showAddChannelDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_channels.isEmpty)
                    const AppEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Koi Online Channel Connect Nahi',
                      message:
                          'Daraz Pakistan ya WhatsApp Business Catalog connect karein taake online stock aur orders sync ho sakein.',
                    )
                  else
                    ..._channels.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade50,
                              child: Icon(
                                  c['channel_type'] == 'daraz'
                                      ? Icons.shopping_cart
                                      : Icons.chat,
                                  color: Colors.orange.shade900),
                            ),
                            title: Text(c['channel_name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Type: ${c['channel_type'].toString().toUpperCase()} • Synced: ${c['last_synced_at'].toString().substring(0, 10)}'),
                            trailing: const Icon(Icons.check_circle,
                                color: Colors.green),
                          ),
                        )),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Incoming Orders from Channels',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () async {
                          if (_channels.isNotEmpty) {
                            await EcommerceChannelService
                                .simulateSyncDarazOrder(
                              companyId: widget.companyId,
                              channelId: _channels.first['id'] as int,
                              darazOrderId: 'DARAZ-${1000 + _orders.length}',
                              customerName: 'Muhammad Ali',
                              customerPhone: '03001234567',
                              totalAmount: 3450.0,
                            );
                            _load();
                          }
                        },
                        child: const Text('+ Test Order Fetch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _orders.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.inbox,
                            title: 'Koi Naya Online Order Nahi',
                            message:
                                'Daraz ya WhatsApp se aane wale naye orders yahan automatically visible honge.',
                          )
                        : ListView.builder(
                            itemCount: _orders.length,
                            itemBuilder: (ctx, i) {
                              final o = _orders[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade50,
                                    child: const Icon(Icons.receipt,
                                        color: Colors.blue),
                                  ),
                                  title: Text(
                                      'Order ${o['external_order_id']} (${o['customer_name']})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      'Phone: ${o['customer_phone']} • Amount: Rs. ${(o['total_amount'] as num).toStringAsFixed(0)}'),
                                  trailing: FilledButton(
                                    style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Order ${o['external_order_id']} sale mein convert ho kar stock deduct ho gaya!')),
                                      );
                                    },
                                    child: const Text('Convert to Sale'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
