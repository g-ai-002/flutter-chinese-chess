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
}
