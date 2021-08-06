import 'package:rtchat/models/message.dart';

class TwitchSubscriptionMessageEventModel extends MessageModel {
  final String subscriberUserName;
  final String tier;
  final int cumulativeMonths;
  final int durationMonths;
  final int streakMonths;

  const TwitchSubscriptionMessageEventModel(
      {required bool pinned,
      required String messageId,
      required this.subscriberUserName,
      required this.tier,
      required this.cumulativeMonths,
      required this.durationMonths,
      required this.streakMonths})
      : super(messageId: messageId, pinned: pinned);
}
