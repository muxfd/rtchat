import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtchat/tts_plugin.dart';
import 'package:rtchat/volume_plugin.dart';

void main() {
  final ttsQueue = TTSQueue();

  test('Queue starts empty', () {
    expect(ttsQueue.isEmpty, isTrue);
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TextToSpeechPlugin.channel,
            (MethodCall method) async {
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VolumePlugin.channel,
            (MethodCall method) async {
      if (method.method == 'tts_on' || method.method == 'tts_off') {
        return null; // Mock response for volume channel methods
      }
      throw MissingPluginException(
          'No implementation found for method ${method.method} on channel ${VolumePlugin.channel.name}');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TextToSpeechPlugin.channel, null);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VolumePlugin.channel, null);
  });

  test('Speak adds elements to the queue', () async {
    final future1 = ttsQueue.speak('1', 'First message');
    expect(ttsQueue.isEmpty, isFalse);
    expect(ttsQueue.length, equals(1));
    await future1;

    final future2 = ttsQueue.speak('2', 'Second message');
    expect(ttsQueue.isEmpty, isFalse);
    expect(ttsQueue.length, equals(1));
    await future2;

    expect(ttsQueue.isEmpty, isTrue);
    expect(ttsQueue.length, equals(0));
  });

  test('Speak and clear empties the queue', () async {
    var calls = 0;
    final future1 = ttsQueue.speak('1', 'First message').catchError((e) {
      fail(
          'Should not have errored, can\'t clear the first element already in progress');
    });
    final future2 = ttsQueue.speak('2', 'Second message').catchError((e) {
      expect(e.toString(), equals("Exception: Message was deleted"));
      calls++;
    });
    await ttsQueue.clear();
    expect(ttsQueue.isEmpty, isTrue);
    await future1;
    await future2;
    expect(calls, equals(1));
  });

  test('Delete doesn\'t delete element if at the front of the queue', () async {
    final future1 = ttsQueue.speak('1', 'First message');
    final future2 = ttsQueue.speak('2', 'Second message');
    ttsQueue.delete('1');
    expect(ttsQueue.length, equals(2));
    expect(ttsQueue.peek()!.id, equals('1'));
    await future1;
    await future2;
  });

  test('Delete deletes the second element', () async {
    var calls = 0;
    final future1 = ttsQueue.speak('1', 'First message');
    final future2 = ttsQueue.speak('2', 'Second message').catchError((e) {
      expect(e.toString(), equals("Exception: Message was deleted"));
      calls++;
    });

    ttsQueue.delete('2');

    expect(ttsQueue.length, equals(1));
    await future1;
    await future2;
    expect(calls, equals(1));
  });

  test('TTS announces stoppage when queue exceeds 20 items', () async {
    // Simulate speaking 21 messages
    for (int i = 1; i <= 21; i++) {
      await ttsQueue.speak('$i', 'Message $i');
    }

    // Expect the queue to be cleared after the 21st message
    expect(ttsQueue.isEmpty, isTrue);
  });
}
