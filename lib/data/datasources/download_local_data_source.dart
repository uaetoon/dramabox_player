import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/download_item.dart';

abstract class DownloadLocalDataSource {
  Future<void> saveDownload(DownloadItem item);
  Future<List<DownloadItem>> getDownloads();
  Future<DownloadItem?> getDownload(String id);
  Future<void> removeDownload(String id);
}

class DownloadLocalDataSourceImpl implements DownloadLocalDataSource {
  static const String downloadsBox = 'downloads_box';

  static String _hiveKey(String raw) {
    var hash = 0xcbf29ce484222325;
    for (final unit in raw.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'k$hash';
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    final box = await Hive.openBox(downloadsBox);
    await box.put(_hiveKey(item.id), jsonEncode(item.toJson()));
  }

  @override
  Future<List<DownloadItem>> getDownloads() async {
    final box = await Hive.openBox(downloadsBox);
    final result = <DownloadItem>[];
    for (final value in box.values) {
      if (value is String) {
        try {
          result.add(DownloadItem.fromJson(jsonDecode(value)));
        } catch (_) {
          // ignore malformed entries
        }
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<DownloadItem?> getDownload(String id) async {
    final box = await Hive.openBox(downloadsBox);
    final value = box.get(_hiveKey(id));
    if (value is String) {
      try {
        return DownloadItem.fromJson(jsonDecode(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> removeDownload(String id) async {
    final box = await Hive.openBox(downloadsBox);
    await box.delete(_hiveKey(id));
  }
}
