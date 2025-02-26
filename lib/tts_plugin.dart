import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rtchat/main.dart';
import 'package:rtchat/notifications_plugin.dart';
import 'package:rtchat/volume_plugin.dart';

class TextToSpeechPlugin {
  static const MethodChannel channel = MethodChannel('ttsPlugin');

  static Future<void> updateTTSPreferences(double pitch, double speed) async {
    try {
      await channel.invokeMethod(
          'updateTTSPreferences', {'pitch': pitch, 'speed': speed});
    } catch (e) {
      debugPrint("updateTTSPreferences error: $e");
    }
  }

  static Future<void> speak(String text,
      {double? speed, double? volume}) async {
    try {
      await channel.invokeMethod(
          'speak', {'text': text, 'speed': speed, 'volume': volume});
    } catch (e) {
      debugPrint("speak error: $e");
    }
  }

  static Future<Map<String, String>> getLanguages() async {
    try {
      final Map<dynamic, dynamic> languageMap =
          await channel.invokeMethod('getLanguages');
      return Map<String, String>.from(languageMap);
    } catch (e) {
      debugPrint("getLanguages error: $e");
      return <String, String>{};
    }
  }

  static Future<void> stopSpeaking() async {
    try {
      await channel.invokeMethod('stopSpeaking');
    } catch (e) {
      debugPrint("stopSpeaking error: $e");
    }
  }

  static Future<void> disableTTS() async {
    try {
      await channel.invokeMethod('disableTTS');
    } catch (e) {
      debugPrint("disableTTS error: $e");
    }
  }

  static Future<void> clear() async {
    try {
      await channel.invokeMethod('clear');
    } catch (e) {
      debugPrint("clear error: $e");
    }
  }
}

class TTSQueue {
  final Queue<TTSQueueElement> queue = Queue<TTSQueueElement>();
  var _lastMessageTime = DateTime.now();

  bool get isEmpty => queue.isEmpty;
  int get length => queue.length;

  Future<void> speak(String id, String text,
      {double? speed, double? volume, DateTime? timestamp}) async {
    final completer = Completer<void>();
    final element = TTSQueueElement(id: id, text: text, completer: completer);

    if (timestamp != null && timestamp.isBefore(_lastMessageTime)) {
      return;
    }
    _lastMessageTime = timestamp ?? DateTime.now();

    if (queue.length >= 20 && !readUserName) {
      queue.clear();
      await clear();
      await disableTts();
      await TextToSpeechPlugin.stopSpeaking();
      await TextToSpeechPlugin.speak(
          "There are too many messages. Text to speech disabled");
      NotificationsPlugin.cancelNotification();
      return;
    }

    if (queue.isNotEmpty) {
      VolumePlugin.reduceVolumeOnTtsStart();
      final previous = queue.last;
      queue.addLast(element);
      await previous.completer.future;
      if (queue.firstOrNull != element) {
        throw Exception('Message was deleted');
      }
      await TextToSpeechPlugin.speak(text, speed: speed ?? 1.5, volume: volume);
      completer.complete();

      if (isEmpty) {
        VolumePlugin.increaseVolumeOnTtsStop();
      }
    } else {
      queue.addLast(element);
      await TextToSpeechPlugin.speak(text, speed: speed ?? 1.5, volume: volume);
      completer.complete();

      if (isEmpty) {
        VolumePlugin.increaseVolumeOnTtsStop();
      }
    }
    queue.remove(element);
  }

  bool get readUserName => queue.length < 10;

  void delete(String id) {
    if (queue.isNotEmpty && queue.first.id != id) {
      queue.removeWhere((element) => element.id == id);
    }
  }

  Future<void> clear() async {
    queue.clear();
  }

  TTSQueueElement? peek() {
    return queue.isNotEmpty ? queue.first : null;
  }

  Future<void> disableTts() async {
    updateChannelSubscription("");
    TextToSpeechPlugin.disableTTS();
  }
}

class TTSQueueElement {
  final String id;
  final String text;
  final Completer<void> completer;

  TTSQueueElement(
      {required this.id, required this.text, required this.completer});
}
