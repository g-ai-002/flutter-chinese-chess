import 'package:chinese_chess/game/logic_rate.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('未设置难度时默认为高手', () async {
    final storage = await StorageService.instance;
    expect(storage.difficulty, Difficulty.expert);
  });

  test('无法识别的难度值回退到高手', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyDifficulty: 'unknown',
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    expect(storage.difficulty, Difficulty.expert);
  });

  test('未设置逻辑刷新率时默认为 60Hz', () async {
    final storage = await StorageService.instance;
    expect(storage.logicRate, LogicRate.hz60);
  });

  test('无法识别的逻辑刷新率回退到 60Hz', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyLogicRate: 'hz999',
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    expect(storage.logicRate, LogicRate.hz60);
  });

  test('逻辑刷新率写入后重新加载仍生效', () async {
    final storage = await StorageService.instance;
    await storage.setLogicRate(LogicRate.hz120);
    StorageService.resetForTests();
    expect((await StorageService.instance).logicRate, LogicRate.hz120);
  });
}
