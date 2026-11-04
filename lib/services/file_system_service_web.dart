/// Web 平台文件系统服务：浏览器没有可写的本地目录。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance = FileSystemService._(
    'FlutterChineseChess',
  );

  final String appDirName;

  Future<String> getLogRootPath() async => '';

  Future<String?> saveText(String fileName, String content) async => null;

  /// 浏览器没有本地棋谱目录，导入统一使用粘贴文本。
  Future<List<String>> listRecordFiles() async => const [];

  Future<String?> readRecordFile(String fileName) async => null;

  Future<bool> openDirectory(String path) async => false;
}
