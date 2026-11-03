import 'dart:typed_data';

import 'package:chinese_chess/services/music_service.dart';
import 'package:chinese_chess/services/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

int _peak(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  var peak = 0;
  for (var offset = 44; offset + 1 < wav.length; offset += 2) {
    final value = data.getInt16(offset, Endian.little).abs();
    if (value > peak) peak = value;
  }
  return peak;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('背景音乐是 16 秒循环的合法 16 位单声道 WAV', () {
    final wav = synthesizeMusicWav();
    final data = ByteData.sublistView(wav);
    final expectedSamples = (kMusicLoopSeconds * kMusicSampleRate).round();

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint16(20, Endian.little), 1, reason: 'PCM 编码');
    expect(data.getUint16(22, Endian.little), 1, reason: '单声道');
    expect(data.getUint32(24, Endian.little), kMusicSampleRate);
    expect(data.getUint16(34, Endian.little), 16, reason: '16 位采样');
    expect(data.getUint32(40, Endian.little), expectedSamples * 2);
    expect(wav.length, 44 + expectedSamples * 2);
    expect(_peak(wav), greaterThan(8000));
  });

  test('背景音乐首尾淡入淡出，循环处不产生爆音', () {
    final wav = synthesizeMusicWav();
    final data = ByteData.sublistView(wav);
    final first = data.getInt16(44, Endian.little).abs();
    final last = data.getInt16(wav.length - 2, Endian.little).abs();

    expect(first, lessThan(400));
    expect(last, lessThan(400));
  });

  test('背景音乐开关通过播放出口生效', () async {
    final states = <bool>[];
    MusicService.reset();
    MusicService.sink = states.add;
    addTearDown(MusicService.reset);

    await MusicService.setEnabled(false);
    await MusicService.setEnabled(true);

    expect(states, [false, true]);
  });
}
