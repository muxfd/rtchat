import 'package:flutter/services.dart';

class VolumePlugin {
  static const MethodChannel channel = MethodChannel('volume_channel');

  static Future<void> reduceVolumeOnTtsStart() async {
    await channel.invokeMethod('tts_on');
  }

  static Future<void> increaseVolumeOnTtsStop() async {
    await channel.invokeMethod('tts_off');
  }
}
