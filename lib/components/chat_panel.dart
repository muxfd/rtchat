import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/chat_history/message.dart';
import 'package:rtchat/components/pinnable/scroll_view.dart';
import 'package:rtchat/components/style_model_theme.dart';
import 'package:rtchat/models/channels.dart';
import 'package:rtchat/models/messages.dart';
import 'package:rtchat/models/messages/message.dart';
import 'package:rtchat/models/messages/twitch/channel_point_redemption_event.dart';
import 'package:rtchat/models/messages/twitch/event.dart';
import 'package:rtchat/models/messages/twitch/eventsub_configuration.dart';
import 'package:rtchat/models/messages/twitch/hype_train_event.dart';
import 'package:rtchat/models/messages/twitch/message.dart';
import 'package:rtchat/models/messages/twitch/message_configuration.dart';
import 'package:rtchat/models/messages/twitch/prediction_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_gift_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_message_event.dart';

class _RebuildableWidget extends StatefulWidget {
  final Widget Function(BuildContext) builder;
  final Set<DateTime> rebuildAt;

  const _RebuildableWidget(
      {Key? key, required this.builder, required this.rebuildAt})
      : super(key: key);

  @override
  _RebuildableWidgetState createState() => _RebuildableWidgetState();
}

class _RebuildableWidgetState extends State<_RebuildableWidget> {
  Set<Timer> timers = {};

  @override
  void initState() {
    super.initState();

    _setTimers();
  }

  @override
  void didUpdateWidget(_RebuildableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    _clearTimers();
    _setTimers();
  }

  @override
  void dispose() {
    super.dispose();

    _clearTimers();
  }

  void _setTimers() {
    final now = DateTime.now();
    timers = widget.rebuildAt.expand((dateTime) sync* {
      final duration = dateTime.difference(now);
      if (!duration.isNegative) {
        yield Timer(duration, () => setState(() {}));
      }
    }).toSet();
  }

  void _clearTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

DateTime? _getExpiration(
    MessageModel model,
    EventSubConfigurationModel eventSubConfigurationModel,
    TwitchMessageConfig twitchMessageConfig) {
  if (model is TwitchRaidEventModel) {
    final raidEventConfig = eventSubConfigurationModel.raidEventConfig;
    return raidEventConfig.eventDuration > Duration.zero
        ? model.timestamp.add(raidEventConfig.eventDuration)
        : null;
  } else if (model is TwitchHostEventModel) {
    final hostEventConfig = eventSubConfigurationModel.hostEventConfig;
    return hostEventConfig.eventDuration > Duration.zero
        ? model.timestamp.add(hostEventConfig.eventDuration)
        : null;
  } else if (model is TwitchFollowEventModel) {
    final followEventConfig = eventSubConfigurationModel.followEventConfig;
    return followEventConfig.eventDuration > Duration.zero
        ? model.timestamp.add(followEventConfig.eventDuration)
        : null;
  } else if (model is TwitchCheerEventModel) {
    final cheerEventConfig = eventSubConfigurationModel.cheerEventConfig;
    return cheerEventConfig.eventDuration > Duration.zero
        ? model.timestamp.add(cheerEventConfig.eventDuration)
        : null;
  } else if (model is TwitchSubscriptionEventModel ||
      model is TwitchSubscriptionGiftEventModel ||
      model is TwitchSubscriptionMessageEventModel) {
    final subEventConfig = eventSubConfigurationModel.subscriptionEventConfig;
    return subEventConfig.eventDuration > Duration.zero
        ? model.timestamp.add(subEventConfig.eventDuration)
        : null;
  } else if (model is TwitchPollEventModel) {
    final pollEventConfig = eventSubConfigurationModel.pollEventConfig;
    if (model.status == 'archived' || model.status == 'terminated') {
      return null;
    }
    return model.endTimestamp.add(pollEventConfig.eventDuration);
  } else if (model is TwitchChannelPointRedemptionEventModel) {
    final channelPointRedemptionEventConfig =
        eventSubConfigurationModel.channelPointRedemptionEventConfig;
    final unfulfilledDuration =
        channelPointRedemptionEventConfig.eventDuration +
            channelPointRedemptionEventConfig.unfulfilledAdditionalDuration;

    if (model.status == TwitchChannelPointRedemptionStatus.unfulfilled &&
        unfulfilledDuration > Duration.zero) {
      return model.timestamp.add(unfulfilledDuration);
    }
    if (model.status == TwitchChannelPointRedemptionStatus.fulfilled &&
        channelPointRedemptionEventConfig.eventDuration > Duration.zero) {
      return model.timestamp
          .add(channelPointRedemptionEventConfig.eventDuration);
    }
    return null;
  } else if (model is TwitchHypeTrainEventModel) {
    final hypetrainEventConfig =
        eventSubConfigurationModel.hypetrainEventConfig;
    return model.endTimestamp.add(hypetrainEventConfig.eventDuration);
  } else if (model is TwitchPredictionEventModel) {
    final predictionEventConfig =
        eventSubConfigurationModel.predictionEventConfig;

    if (model.status == 'canceled') {
      return null;
    }

    return model.endTime.add(predictionEventConfig.eventDuration);
  } else if (model is TwitchMessageModel) {
    if (model.isModerator) {
      return twitchMessageConfig.modMessageDuration > Duration.zero
          ? model.timestamp.add(twitchMessageConfig.modMessageDuration)
          : null;
    } else if (model.isVip) {
      return twitchMessageConfig.vipMessageDuration > Duration.zero
          ? model.timestamp.add(twitchMessageConfig.vipMessageDuration)
          : null;
    }
    return null;
  }
  return null;
}

class _ScrollToBottomWidget extends StatefulWidget {
  final ScrollController controller;

  const _ScrollToBottomWidget({Key? key, required this.controller})
      : super(key: key);

  @override
  State<_ScrollToBottomWidget> createState() => _ScrollToBottomWidgetState();
}

class _ScrollToBottomWidgetState extends State<_ScrollToBottomWidget> {
  var _atBottom = true;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(updateScrollPosition);
  }

  @override
  void dispose() {
    widget.controller.removeListener(updateScrollPosition);

    super.dispose();
  }

  void updateScrollPosition() {
    final value =
        widget.controller.position.atEdge && widget.controller.offset == 0;
    if (_atBottom != value) {
      setState(() {
        _atBottom = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _atBottom ? -72 : 16,
      curve: Curves.easeOut,
      child: Center(
        child: ElevatedButton(
            onPressed: () {
              updateScrollPosition();
              widget.controller.animateTo(0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut);
            },
            style: ElevatedButton.styleFrom(
              primary: Theme.of(context).primaryColor,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.arrow_downward, color: Colors.white)),
      ),
    );
  }
}

class ChatPanelWidget extends StatefulWidget {
  final Channel channel;

  const ChatPanelWidget({required this.channel, Key? key}) : super(key: key);

  @override
  _ChatPanelWidgetState createState() => _ChatPanelWidgetState();
}

class _ChatPanelWidgetState extends State<ChatPanelWidget>
    with TickerProviderStateMixin {
  final _controller = ScrollController(keepScrollOffset: true);

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.topCenter,
      children: [
        Consumer3<MessagesModel, EventSubConfigurationModel,
                TwitchMessageConfig>(
            builder: (context, messagesModel, eventSubConfigurationModel,
                twitchMessageConfig, child) {
          final messages = messagesModel.messages.reversed.toList();
          final expirations = messages
              .map((message) => _getExpiration(
                  message, eventSubConfigurationModel, twitchMessageConfig))
              .toList();
          return _RebuildableWidget(
              rebuildAt: expirations.whereType<DateTime>().toSet(),
              builder: (context) {
                final now = DateTime.now();
                return PinnableMessageScrollView(
                  vsync: this,
                  controller: _controller,
                  itemBuilder: (index) => StyleModelTheme(
                      child: ChatHistoryMessage(
                          key: ValueKey(messages[index].messageId),
                          message: messages[index],
                          channel: widget.channel)),
                  isPinnedBuilder: (index) {
                    final expiration = expirations[index];
                    return expiration != null && expiration.isAfter(now);
                  },
                  count: messages.length,
                );
              });
        }),
        _ScrollToBottomWidget(controller: _controller),
      ],
    );
  }
}
