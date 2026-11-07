import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/logic_rate.dart';
import '../models/game_models.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../theme/board_skin.dart';

/// 用户偏好：主题、棋盘皮肤、难度、先后手、走法提示与音效。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _syncFeedback();
  }

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) =>
      _update(() => _storage.setDarkMode(value));

  Difficulty get difficulty => _storage.difficulty;
  Future<void> setDifficulty(Difficulty value) =>
      _update(() => _storage.setDifficulty(value));

  int get humanSide => _storage.humanSide;
  Future<void> setHumanSide(int value) =>
      _update(() => _storage.setHumanSide(value));

  BoardSkin get boardSkin => boardSkinOf(_storage.boardSkinId);
  Future<void> setBoardSkin(BoardSkin value) =>
      _update(() => _storage.setBoardSkinId(value.id));

  bool get soundEnabled => _storage.soundEnabled;
  Future<void> setSoundEnabled(bool value) => _update(() async {
    await _storage.setSoundEnabled(value);
    _syncFeedback();
  });

  bool get musicEnabled => _storage.musicEnabled;
  Future<void> setMusicEnabled(bool value) => _update(() async {
    await _storage.setMusicEnabled(value);
    // 音频启停不阻塞开关反馈，加载失败时 MusicService 自行记录日志。
    unawaited(MusicService.setEnabled(value));
  });

  bool get hapticsEnabled => _storage.hapticsEnabled;
  Future<void> setHapticsEnabled(bool value) => _update(() async {
    await _storage.setHapticsEnabled(value);
    _syncFeedback();
  });

  bool get showHints => _storage.showHints;
  Future<void> setShowHints(bool value) =>
      _update(() => _storage.setShowHints(value));

  bool get showOpeningHints => _storage.showOpeningHints;
  Future<void> setShowOpeningHints(bool value) =>
      _update(() => _storage.setShowOpeningHints(value));

  TimeControl get timeControl => _storage.timeControl;
  Future<void> setTimeControl(TimeControl value) =>
      _update(() => _storage.setTimeControl(value));

  LogicRate get logicRate => _storage.logicRate;
  Future<void> setLogicRate(LogicRate value) =>
      _update(() => _storage.setLogicRate(value));

  bool isPuzzleSolved(String id) => _storage.isPuzzleSolved(id);
  int? puzzleBestMoves(String id) => _storage.puzzleBestMoves(id);

  Future<void> recordPuzzleCleared(String id, int moves) =>
      _update(() => _storage.recordPuzzleCleared(id, moves));

  void _syncFeedback() =>
      SoundService.configure(sound: soundEnabled, haptics: hapticsEnabled);

  /// 写入偏好后统一通知界面，避免每个 setter 重复一遍。
  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
