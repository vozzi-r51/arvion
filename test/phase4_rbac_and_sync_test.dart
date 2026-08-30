import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/auth/permission_service.dart';
import 'package:bizmanager/core/widgets/permission_gate.dart';
import 'package:bizmanager/core/sync/sync_broker_service.dart';
import 'package:bizmanager/core/sync/hlc.dart';
import 'package:bizmanager/core/utils/uuid_v7.dart';

class MockWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<dynamic> stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  Future get done => Future.value();
}

class MockWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> controller = StreamController<dynamic>();
  final MockWebSocketSink mockSink = MockWebSocketSink();

  @override
  Stream<dynamic> get stream => controller.stream;

  @override
  WebSocketSink get sink => mockSink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 4 Granular RBAC Matrix & WebSocket Sync Broker Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'RBAC Test Company ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
      PermissionService().setActivePermissions({'sales.create', 'purchases.create', 'accounts.journal.post'});
    });

    test('a) Session without sales.void throws PermissionDeniedException on voidSale', () async {
      final saleId = await db.insertSaleWithItems(
        sale: {
          'company_id': companyId,
          'invoice_number': 'INV-RBAC-001',
          'sale_type': 'cash',
          'subtotal': 500.0,
          'total_amount': 500.0,
          'paid_amount': 500.0,
          'due_amount': 0.0,
          'sale_date': DateTime.now().toIso8601String(),
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        },
        items: [
          {
            'product_name': 'Test Item',
            'quantity': 1.0,
            'unit_price': 500.0,
            'total': 500.0,
          }
        ],
      );

      expect(saleId, isPositive);

      // Active permissions currently lack 'sales.void'
      expect(
        () async => await db.voidSale(saleId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    testWidgets('b) PermissionGate renders fallback when key is missing and child when present', (tester) async {
      PermissionService().setActivePermissions({'sales.create'});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PermissionGate(
                  permission: 'sales.create',
                  fallback: Text('No Access Sale Create'),
                  child: Text('Allowed Sale Create'),
                ),
                PermissionGate(
                  permission: 'sales.void',
                  fallback: Text('No Access Sale Void'),
                  child: Text('Allowed Sale Void'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Allowed Sale Create'), findsOneWidget);
      expect(find.text('No Access Sale Void'), findsOneWidget);
      expect(find.text('Allowed Sale Void'), findsNothing);
    });

    test('c) Mock WebSocket channel ingests remote SYNC_DELTAS and updates local tables', () async {
      final mockChannel = MockWebSocketChannel();

      final broker = SyncBrokerService(
        serverUrl: 'ws://localhost:8080',
        nodeId: 'NODE-LOCAL-001',
        companyId: companyId.toString(),
        authToken: 'token_xyz',
        channelOverride: mockChannel,
      );

      final remoteHlc = HLC.now('NODE-REMOTE-999');

      final messagePayload = jsonEncode({
        'type': 'SYNC_DELTAS',
        'last_hlc': remoteHlc.toString(),
        'payload': [
          {
            'change_id': UUIDv7.generate(),
            'company_id': companyId.toString(),
            'branch_id': '1',
            'node_id': 'NODE-REMOTE-999',
            'table_name': 'customers',
            'row_id': '9009',
            'hlc_timestamp': remoteHlc.toString(),
            'operation_type': 'INSERT',
            'columns_payload': jsonEncode({
              'company_id': companyId,
              'name': 'Remote Ingested Customer',
              'mobile': '03009998877',
              'status': 'active',
              'created_at': DateTime.now().toIso8601String(),
            }),
          }
        ]
      });

      // Simulate receiving remote WebSocket message
      mockChannel.controller.add(messagePayload);
      await Future.delayed(const Duration(milliseconds: 100));

      final rows = await (await db.database).query(
        'customers',
        where: 'id = ?',
        whereArgs: [9009],
      );

      expect(rows.length, 1);
      expect(rows.first['name'], 'Remote Ingested Customer');

      // Verify acknowledgement was sent back to WebSocket sink
      expect(mockChannel.mockSink.sentMessages.length, isPositive);
      final ackMessage = jsonDecode(mockChannel.mockSink.sentMessages.last as String);
      expect(ackMessage['type'], 'ACK_DELTAS');

      broker.dispose();
    });
  });
}
