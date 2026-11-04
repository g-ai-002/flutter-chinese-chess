import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_game.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 棋谱服务：内存 + SharedPreferences 双写，只保留最近若干局回放。
class GameHistoryService extends ChangeNotifier {
  GameHistoryService._();

  static final GameHistoryService instance = GameHistoryService._();

  static const int maxRecords = 20;

  final List<SavedGame> _records = [];
  SharedPreferences? _prefs;

  List<SavedGame> get records => List.unmodifiable(_records);

  bool get isEmpty => _records.isEmpty;

  @visibleForTesting
  void resetForTest() {
    _records.clear();
    _prefs = null;
  }

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(AppConstants.prefKeyGameHistory);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <SavedGame>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final game = SavedGame.fromJson(item);
          if (game != null) loaded.add(game);
        } catch (_) {
          // 单条损坏不影响其余回放加载。
        }
      }
      loaded.sort((a, b) => b.endedAt.compareTo(a.endedAt));
      _records
        ..clear()
        ..addAll(loaded.take(maxRecords));
      notifyListeners();
    } catch (e, stack) {
      LogService.error('读取棋谱失败', e, stack);
    }
  }

  /// 同一 id 再次写入时覆盖旧记录，避免悔棋后重判产生重复条目。
  Future<void> record(SavedGame game) async {
    _records
      ..removeWhere((item) => item.id == game.id)
      ..insert(0, game);
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
    notifyListeners();
    LogService.info('棋谱已保存: ${game.title}, ${game.moveCount} 手');
    await _persist();
  }

  Future<void> remove(String id) async {
    final before = _records.length;
    _records.removeWhere((item) => item.id == id);
    if (_records.length == before) return;
    notifyListeners();
    LogService.info('已删除棋谱: $id');
    await _persist();
  }

  Future<void> clear() async {
    _records.clear();
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(AppConstants.prefKeyGameHistory);
      LogService.info('已清空棋谱');
    } catch (e, stack) {
      LogService.error('清空棋谱失败', e, stack);
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        AppConstants.prefKeyGameHistory,
        jsonEncode([for (final item in _records) item.toJson()]),
      );
    } catch (e, stack) {
      LogService.error('保存棋谱失败', e, stack);
    }
  }
}
