import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../utils/purchase_channel_labels.dart';
import 'admin_order_service.dart';
import 'admin_user_service.dart';

class AdminUsersExcelExportResult {
  final Uint8List bytes;
  final String fileName;
  final int userCount;
  final int accessCount;
  final int orderCount;

  AdminUsersExcelExportResult({
    required this.bytes,
    required this.fileName,
    required this.userCount,
    required this.accessCount,
    required this.orderCount,
  });
}

class AdminUsersExcelExportService {
  AdminUsersExcelExportService({
    AdminUserService? userService,
    AdminOrderService? orderService,
  }) : _userService = userService ?? AdminUserService(),
       _orderService = orderService ?? AdminOrderService();

  final AdminUserService _userService;
  final AdminOrderService _orderService;

  Future<AdminUsersExportJob> createUsersExportJob({
    Map<String, dynamic> filters = const {},
  }) async {
    final data = await _userService.createUsersExportJob(filters: filters);
    return AdminUsersExportJob.fromJson(
      Map<String, dynamic>.from(data["job"] ?? const {}),
    );
  }

  Future<AdminUsersExportJob> getUsersExportJob(String jobId) async {
    final data = await _userService.getUsersExportJob(jobId);
    return AdminUsersExportJob.fromJson(
      Map<String, dynamic>.from(data["job"] ?? const {}),
    );
  }

  Future<Uint8List> downloadUsersExportJobBytes(String jobId) async {
    return _userService.downloadUsersExportJobBytes(jobId);
  }

  Future<AdminUsersExcelExportResult> exportUsersWorkbook() async {
    final users = await _userService.getAllUsers();
    final userIds = users
        .map((u) => _asInt(u["id"]))
        .whereType<int>()
        .toSet()
        .toList();
    final userIdSet = userIds.toSet();
    final accessRows = await _userService.getExportAccessRecords(
      userIds: userIds,
    );
    final orders = await _orderService.getAllOrders();
    final ordersForExport = orders
        .where((order) => userIdSet.contains(_orderUserId(order)))
        .toList(growable: false);

    final usersById = <int, Map<String, dynamic>>{
      for (final user in users)
        if (_asInt(user["id"]) != null) _asInt(user["id"])!: user,
    };
    final accessByUser = _groupByUserId(accessRows);
    final ordersByUser = _groupByUserId(ordersForExport);

    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Kullanicilar');
    final usersSheet = workbook['Kullanicilar'];
    final accessSheet = workbook['Abonelikler'];
    final ordersSheet = workbook['Siparisler'];

    _writeUsersSheet(
      usersSheet,
      users,
      accessByUser: accessByUser,
      ordersByUser: ordersByUser,
    );
    _writeAccessSheet(accessSheet, accessRows, usersById: usersById);
    _writeOrdersSheet(ordersSheet, ordersForExport, usersById: usersById);

    final fileName = 'kullanicilar_export_${_timestamp()}.xlsx';
    final bytes = workbook.save(fileName: fileName) ?? <int>[];

    return AdminUsersExcelExportResult(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      userCount: users.length,
      accessCount: accessRows.length,
      orderCount: ordersForExport.length,
    );
  }

  void _writeUsersSheet(
    Sheet sheet,
    List<Map<String, dynamic>> users, {
    required Map<int, List<Map<String, dynamic>>> accessByUser,
    required Map<int, List<Map<String, dynamic>>> ordersByUser,
  }) {
    final headers = [
      'ID',
      'Ad Soyad',
      'E-posta',
      'Telefon',
      'Rol',
      'Aktif Abonelik Sayısı',
      'Sipariş Sayısı',
      'Son Abonelik Bitişi',
      'Son Satın Alma Tarihi',
      'Son Satın Alma Kanalı',
      'Aktif Satın Alma Özeti',
    ];
    final rows = users
        .map((user) {
          final userId = _asInt(user['id']);
          final accessRows = userId == null
              ? const <Map<String, dynamic>>[]
              : (accessByUser[userId] ?? const []);
          final orderRows = userId == null
              ? const <Map<String, dynamic>>[]
              : (ordersByUser[userId] ?? const []);
          final latestExpiry = _latestDate(
            accessRows
                .map((row) => _parseDateTime(row['expires_at']))
                .whereType<DateTime>(),
          );
          final latestPurchase = _latestDate([
            ...accessRows
                .map((row) => _parseDateTime(row['started_at']))
                .whereType<DateTime>(),
            ...orderRows
                .map((row) => _parseDateTime(row['created_at']))
                .whereType<DateTime>(),
          ]);
          final latestChannel = _latestChannel(accessRows, orderRows);
          final accessSummary = _summarizeAccess(accessRows);

          return [
            userId?.toString() ?? '-',
            _text(user['name']),
            _text(user['email']),
            _text(user['phone']),
            _text(user['role']),
            accessRows.length.toString(),
            orderRows.length.toString(),
            _formatDateTime(latestExpiry, dateOnly: true),
            _formatDateTime(latestPurchase),
            latestChannel,
            accessSummary,
          ];
        })
        .toList(growable: false);

    _writeTable(
      sheet: sheet,
      headers: headers,
      rows: rows,
      widths: const [10, 24, 28, 18, 16, 18, 14, 20, 20, 18, 44],
    );
  }

  void _writeAccessSheet(
    Sheet sheet,
    List<Map<String, dynamic>> accessRows, {
    required Map<int, Map<String, dynamic>> usersById,
  }) {
    final headers = [
      'Kullanıcı ID',
      'Ad Soyad',
      'E-posta',
      'Telefon',
      'Tür',
      'Ürün',
      'Alt Bilgi',
      'Başlangıç',
      'Bitiş',
      'Fiyat',
      'Kaynak',
      'Kanal',
      'Durum',
      'Not',
    ];

    final rows = accessRows
        .map((row) {
          final userId = _asInt(row['user_id']);
          final user = userId == null ? null : usersById[userId];
          return [
            userId?.toString() ?? _text(row['user_id']),
            _text(user?['name']),
            _text(user?['email']),
            _text(user?['phone']),
            _text(row['item_type_label']),
            _text(row['item_title']),
            _text(row['item_subtitle']),
            _formatDateTime(_parseDateTime(row['started_at'])),
            _formatDateTime(_parseDateTime(row['expires_at']), dateOnly: true),
            _formatPrice(row['purchase_price']),
            _text(row['source'] ?? row['grant_source']),
            _text(row['access_channel_label']),
            _boolLabel(row['is_active'] == true),
            _text(row['note']),
          ];
        })
        .toList(growable: false);

    _writeTable(
      sheet: sheet,
      headers: headers,
      rows: rows,
      widths: const [12, 24, 28, 18, 18, 30, 24, 20, 20, 14, 18, 18, 12, 28],
    );
  }

  void _writeOrdersSheet(
    Sheet sheet,
    List<Map<String, dynamic>> orders, {
    required Map<int, Map<String, dynamic>> usersById,
  }) {
    final headers = [
      'Sipariş ID',
      'Kullanıcı ID',
      'Ad Soyad',
      'E-posta',
      'Tutar',
      'Durum',
      'Ödeme Kanalı',
      'Tarih',
    ];

    final rows = orders
        .map((order) {
          final userId = _orderUserId(order);
          final user = userId == null ? null : usersById[userId];
          return [
            _text(order['id']),
            userId?.toString() ?? '-',
            _text(user?['name'] ?? order['user']?['name']),
            _text(user?['email'] ?? order['user']?['email']),
            _formatPrice(order['total_paid']),
            _orderStatusLabel(order['status']?.toString() ?? ''),
            PurchaseChannelLabels.orderChannelLabel(order),
            _formatDateTime(_parseDateTime(order['created_at'])),
          ];
        })
        .toList(growable: false);

    _writeTable(
      sheet: sheet,
      headers: headers,
      rows: rows,
      widths: const [12, 12, 24, 28, 14, 16, 18, 20],
    );
  }

  void _writeTable({
    required Sheet sheet,
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
  }) {
    final headerStyle = CellStyle(bold: true);

    sheet.setDefaultRowHeight(22);
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.updateCell(
        CellIndex.indexByString('${_columnName(i)}1'),
        TextCellValue(headers[i]),
        cellStyle: headerStyle,
      );
    }

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final excelRow = rowIndex + 2;
      for (var colIndex = 0; colIndex < headers.length; colIndex++) {
        final value = colIndex < row.length ? row[colIndex] : '';
        sheet.updateCell(
          CellIndex.indexByString('${_columnName(colIndex)}$excelRow'),
          TextCellValue(value),
        );
      }
    }
  }

  Map<int, List<Map<String, dynamic>>> _groupByUserId(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final userId = _asInt(row['user_id']) ?? _orderUserId(row);
      if (userId == null) continue;
      grouped.putIfAbsent(userId, () => []).add(row);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final aDate = _parseDateTime(a['expires_at'] ?? a['created_at']);
        final bDate = _parseDateTime(b['expires_at'] ?? b['created_at']);
        return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
    }
    return grouped;
  }

  String _summarizeAccess(List<Map<String, dynamic>> accessRows) {
    if (accessRows.isEmpty) return '-';
    final titles = accessRows
        .take(3)
        .map((row) => _text(row['item_title']))
        .where((value) => value.isNotEmpty && value != '-')
        .toList(growable: false);
    if (titles.isEmpty) return '-';
    final extra = accessRows.length - titles.length;
    if (extra > 0) {
      return '${titles.join(' | ')} (+$extra daha)';
    }
    return titles.join(' | ');
  }

  String _latestChannel(
    List<Map<String, dynamic>> accessRows,
    List<Map<String, dynamic>> orders,
  ) {
    DateTime? latestDate;
    String? latestChannel;

    for (final row in accessRows) {
      final dt = _parseDateTime(row['started_at']);
      if (dt == null) continue;
      if (latestDate == null || dt.isAfter(latestDate)) {
        latestDate = dt;
        latestChannel = _text(row['access_channel_label']);
      }
    }

    for (final order in orders) {
      final dt = _parseDateTime(order['created_at']);
      if (dt == null) continue;
      if (latestDate == null || dt.isAfter(latestDate)) {
        latestDate = dt;
        latestChannel = PurchaseChannelLabels.orderChannelLabel(order);
      }
    }

    return latestChannel ?? '-';
  }

  String _formatPrice(dynamic raw) {
    if (raw == null) return '-';
    final parsed = num.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    if (parsed == 0) return '₺0';
    if (parsed % 1 == 0) {
      return '₺${parsed.toInt()}';
    }
    return '₺${parsed.toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime? dt, {bool dateOnly = false}) {
    if (dt == null) return '-';
    String two(int value) => value.toString().padLeft(2, '0');
    final datePart = '${two(dt.day)}.${two(dt.month)}.${dt.year}';
    if (dateOnly) return datePart;
    return '$datePart ${two(dt.hour)}:${two(dt.minute)}';
  }

  DateTime? _latestDate(Iterable<DateTime> dates) {
    DateTime? latest;
    for (final dt in dates) {
      if (latest == null || dt.isAfter(latest)) {
        latest = dt;
      }
    }
    return latest;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _text(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '-' : text;
  }

  String _boolLabel(bool value) => value ? 'Aktif' : 'Pasif';

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _orderUserId(Map<String, dynamic> order) {
    final direct = _asInt(order['user_id']);
    if (direct != null) return direct;
    return _asInt(order['user']?['id']);
  }

  String _orderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Beklemede';
      case 'paid':
        return 'Ödendi';
      case 'shipped':
        return 'Kargoda';
      case 'delivered':
        return 'Teslim Edildi';
      case 'canceled':
        return 'İptal';
      case 'refunded':
        return 'İade';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  String _columnName(int zeroBasedIndex) {
    var index = zeroBasedIndex + 1;
    final chars = <String>[];
    while (index > 0) {
      final remainder = (index - 1) % 26;
      chars.add(String.fromCharCode(65 + remainder));
      index = (index - 1) ~/ 26;
    }
    return chars.reversed.join();
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class AdminUsersExportJob {
  final String id;
  final String status;
  final String? fileName;
  final String? errorMessage;
  final int totalCount;
  final int accessCount;
  final int orderCount;
  final String? downloadUrl;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AdminUsersExportJob({
    required this.id,
    required this.status,
    required this.fileName,
    required this.errorMessage,
    required this.totalCount,
    required this.accessCount,
    required this.orderCount,
    required this.downloadUrl,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
  });

  bool get isCompleted => status == "completed";
  bool get isFailed => status == "failed";
  bool get isQueued => status == "queued";
  bool get isRunning => status == "running";

  factory AdminUsersExportJob.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return AdminUsersExportJob(
      id: json["id"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "queued",
      fileName: json["file_name"]?.toString(),
      errorMessage: json["error_message"]?.toString(),
      totalCount: toInt(json["total_count"]),
      accessCount: toInt(json["access_count"]),
      orderCount: toInt(json["order_count"]),
      downloadUrl: json["download_url"]?.toString(),
      createdAt: parseDate(json["created_at"]),
      startedAt: parseDate(json["started_at"]),
      completedAt: parseDate(json["completed_at"]),
    );
  }
}
