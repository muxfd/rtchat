import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/chat_history/ad.dart';
import 'package:rtchat/components/chat_history/auxiliary/realtimecash_donation.dart';
import 'package:rtchat/components/chat_history/auxiliary/streamlabs.dart';
import 'package:rtchat/components/chat_history/chat_cleared_event.dart';
import 'package:rtchat/components/chat_history/decorated_event.dart';
import 'package:rtchat/components/chat_history/stream_state_event.dart';
import 'package:rtchat/components/chat_history/timeout_dialog.dart';
import 'package:rtchat/components/chat_history/twitch/channel_point_event.dart';
import 'package:rtchat/components/chat_history/twitch/cheer_event.dart';
import 'package:rtchat/components/chat_history/twitch/follow_event.dart';
import 'package:rtchat/components/chat_history/twitch/host_event.dart';
import 'package:rtchat/components/chat_history/twitch/hype_train_event.dart';
import 'package:rtchat/components/chat_history/twitch/message.dart';
import 'package:rtchat/components/chat_history/twitch/poll_event.dart';
import 'package:rtchat/components/chat_history/twitch/prediction_event.dart';
import 'package:rtchat/components/chat_history/twitch/raid_event.dart';
import 'package:rtchat/components/chat_history/twitch/raiding_event.dart';
import 'package:rtchat/components/chat_history/twitch/subscription_event.dart';
import 'package:rtchat/models/adapters/actions.dart';
import 'package:rtchat/models/channels.dart';
import 'package:rtchat/models/layout.dart';
import 'package:rtchat/models/messages/auxiliary/realtimecash.dart';
import 'package:rtchat/models/messages/auxiliary/streamlabs.dart';
import 'package:rtchat/models/messages/message.dart';
import 'package:rtchat/models/messages/twitch/channel_point_redemption_event.dart';
import 'package:rtchat/models/messages/twitch/event.dart';
import 'package:rtchat/models/messages/twitch/eventsub_configuration.dart';
import 'package:rtchat/models/messages/twitch/hype_train_event.dart';
import 'package:rtchat/models/messages/twitch/message.dart';
import 'package:rtchat/models/messages/twitch/prediction_event.dart';
import 'package:rtchat/models/messages/twitch/raiding_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_gift_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_message_event.dart';
import 'package:rtchat/models/tts.dart';
import 'package:rtchat/models/user.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ChatHistoryMessage extends StatelessWidget {
  final MessageModel message;
  final Channel channel;

  const ChatHistoryMessage(
      {Key? key, required this.message, required this.channel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m is TwitchMessageModel) {
      return Consumer<LayoutModel>(builder: (context, layoutModel, child) {
        final announcement = m.annotations.announcement;
        final child = announcement != null
            ? DecoratedEventWidget(
                accentColor: announcement.color,
                child: TwitchMessageWidget(m),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TwitchMessageWidget(m),
              );
        if (layoutModel.locked) {
          return child;
        }
        final userModel = Provider.of<UserModel>(context, listen: false);
        final loginChannelId = userModel.userChannel?.channelId;
        final viewingChannelId = m.channelId.split(':')[1];
        final channel = Channel("twitch", viewingChannelId, "");

        if (loginChannelId != viewingChannelId) {
          return child;
        }

        return Material(
          child: InkWell(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              onLongPress: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                var showTimeoutDialog = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        child: ListView(
                            shrinkWrap: true,
                            primary: false,
                            children: [
                              if (kDebugMode) Text("DEBUG: id=${m.messageId}"),
                              Consumer<TtsModel>(
                                  builder: (context, ttsModel, child) {
                                if (ttsModel.isMuted(m.author)) {
                                  return ListTile(
                                      leading: const Icon(
                                          Icons.volume_up_rounded,
                                          color: Colors.deepPurpleAccent),
                                      title: Text(
                                          'Unmute ${m.author.displayName}'),
                                      onTap: () {
                                        ttsModel.unmute(m.author);
                                        Navigator.pop(context);
                                      });
                                }
                                return ListTile(
                                    leading: const Icon(
                                        Icons.volume_off_rounded,
                                        color: Colors.redAccent),
                                    title: Text('Mute ${m.author.displayName}'),
                                    onTap: () {
                                      ttsModel.mute(m.author);
                                      Navigator.pop(context);
                                    });
                              }),
                              ListTile(
                                  leading: const Icon(Icons.delete,
                                      color: Colors.redAccent),
                                  title: const Text('Delete Message'),
                                  onTap: () {
                                    ActionsAdapter.instance
                                        .delete(channel, m.messageId);
                                    Navigator.pop(context);
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.timer_outlined,
                                      color: Colors.orangeAccent),
                                  title:
                                      Text('Timeout ${m.author.displayName}'),
                                  onTap: () {
                                    Navigator.pop(context, true);
                                  }),
                              ListTile(
                                  leading: const Icon(
                                      Icons.dnd_forwardslash_outlined,
                                      color: Colors.redAccent),
                                  title: Text('Ban ${m.author.displayName}'),
                                  onTap: () {
                                    ActionsAdapter.instance
                                        .ban(channel, m.author.login);
                                    Navigator.pop(context);
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.circle_outlined,
                                      color: Colors.greenAccent),
                                  title: Text('Unban ${m.author.displayName}'),
                                  onTap: () {
                                    ActionsAdapter.instance
                                        .unban(channel, m.author.login);
                                    Navigator.pop(context);
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.copy_outlined,
                                      color: Colors.greenAccent),
                                  title: const Text('Copy message'),
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: m.message));
                                    Navigator.pop(context);
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.link_outlined,
                                      color: Colors.blueAccent),
                                  title: Text(
                                      'View ${m.author.displayName}\'s profile'),
                                  onTap: () {
                                    launchUrlString(
                                        "https://www.twitch.tv/${m.author.displayName}");
                                    Navigator.pop(context);
                                  }),
                            ]),
                      );
                    });
                if (showTimeoutDialog == true) {
                  await showDialog(
                      context: context,
                      builder: (context) {
                        return TimeoutDialog(
                            title: "Timeout ${m.author.displayName}",
                            onPressed: (duration) {
                              ActionsAdapter.instance.timeout(
                                  channel,
                                  m.author.login,
                                  "timed out by streamer",
                                  duration);
                              Navigator.pop(context);
                            });
                      });
                }
              },
              child: child),
        );
      });
    } else if (m is TwitchRaidEventModel) {
      return Selector<EventSubConfigurationModel, RaidEventConfig>(
        selector: (_, model) => model.raidEventConfig,
        builder: (_, config, __) => config.showEvent
            ? TwitchRaidEventWidget(m, channel: channel)
            : Container(),
      );
    } else if (m is TwitchSubscriptionEventModel) {
      return Selector<EventSubConfigurationModel, SubscriptionEventConfig>(
        selector: (_, model) => model.subscriptionEventConfig,
        builder: (_, config, __) =>
            config.showEvent || (config.showIndividualGifts && m.isGift)
                ? TwitchSubscriptionEventWidget(m)
                : Container(),
      );
    } else if (m is TwitchSubscriptionGiftEventModel) {
      return Selector<EventSubConfigurationModel, SubscriptionEventConfig>(
        selector: (_, model) => model.subscriptionEventConfig,
        builder: (_, config, __) => config.showEvent
            ? TwitchSubscriptionGiftEventWidget(m)
            : Container(),
      );
    } else if (m is TwitchSubscriptionMessageEventModel) {
      return Selector<EventSubConfigurationModel, SubscriptionEventConfig>(
        selector: (_, model) => model.subscriptionEventConfig,
        builder: (_, config, __) => config.showEvent
            ? TwitchSubscriptionMessageEventWidget(m)
            : Container(),
      );
    } else if (m is StreamStateEventModel) {
      return StreamStateEventWidget(m);
    } else if (m is TwitchFollowEventModel) {
      return Selector<EventSubConfigurationModel, FollowEventConfig>(
        selector: (_, model) => model.followEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchFollowEventWidget(m) : Container(),
      );
    } else if (m is TwitchCheerEventModel) {
      return Selector<EventSubConfigurationModel, CheerEventConfig>(
        selector: (_, model) => model.cheerEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchCheerEventWidget(m) : Container(),
      );
    } else if (m is TwitchPollEventModel) {
      return Selector<EventSubConfigurationModel, PollEventConfig>(
        selector: (_, model) => model.pollEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchPollEventWidget(m) : Container(),
      );
    } else if (m is TwitchChannelPointRedemptionEventModel) {
      return Selector<EventSubConfigurationModel,
          ChannelPointRedemptionEventConfig>(
        selector: (_, model) => model.channelPointRedemptionEventConfig,
        builder: (_, config, __) => config.showEvent
            ? TwitchChannelPointRedemptionEventWidget(m)
            : Container(),
      );
    } else if (m is TwitchHypeTrainEventModel) {
      return Selector<EventSubConfigurationModel, HypetrainEventConfig>(
        selector: (_, model) => model.hypetrainEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchHypeTrainEventWidget(m) : Container(),
      );
    } else if (m is TwitchPredictionEventModel) {
      return Selector<EventSubConfigurationModel, PredictionEventConfig>(
        selector: (_, model) => model.predictionEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchPredictionEventWidget(m) : Container(),
      );
    } else if (m is TwitchHostEventModel) {
      return Selector<EventSubConfigurationModel, HostEventConfig>(
        selector: (_, model) => model.hostEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchHostEventWidget(m) : Container(),
      );
    } else if (m is TwitchRaidingEventModel) {
      return Selector<EventSubConfigurationModel, RaidingEventConfig>(
        selector: (_, model) => model.raidingEventConfig,
        builder: (_, config, __) =>
            config.showEvent ? TwitchRaidingEventWidget(m) : Container(),
      );
    } else if (m is ChatClearedEventModel) {
      return ChatClearedEventWidget(m);
    } else if (m is AdMessageModel) {
      return AdMessageWidget(m);
    } else if (m is StreamlabsDonationEventModel) {
      return StreamlabsDonationEventWidget(m);
    } else if (m is SimpleRealtimeCashDonationEventModel) {
      return RealtimeCashDonationEventWidget(m);
    } else {
      throw AssertionError("invalid message type $m");
    }
  }
}
