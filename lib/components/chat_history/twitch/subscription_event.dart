import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/chat_history/decorated_event.dart';
import 'package:rtchat/components/image/resilient_network_image.dart';
import 'package:rtchat/models/messages/tokens.dart';
import 'package:rtchat/models/messages/twitch/subscription_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_gift_event.dart';
import 'package:rtchat/models/messages/twitch/subscription_message_event.dart';
import 'package:rtchat/models/style.dart';
import 'package:rtchat/models/user.dart';
import 'package:styled_text/styled_text.dart';

Color tierColor(BuildContext context, String tier) {
  if (tier == '2000') {
    return const Color(0xFF9A93A9);
  } else if (tier == '3000') {
    return const Color(0xFFC09C39);
  } else {
    return Theme.of(context).colorScheme.primary;
  }
}

class TwitchSubscriptionEventWidget extends StatelessWidget {
  final TwitchSubscriptionEventModel model;

  const TwitchSubscriptionEventWidget(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return DecoratedEventWidget.icon(
      icon: Icons.star,
      child: StyledText(
        text: AppLocalizations.of(context)!.subscriptionEvent(
            model.subscriberUserName, model.tier.replaceAll("000", "")),
        tags: {
          'b': StyledTextTag(style: Theme.of(context).textTheme.titleSmall),
        },
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: tierColor(context, model.tier)),
      ),
    );
  }
}

class TwitchSubscriptionGiftEventWidget extends StatelessWidget {
  final TwitchSubscriptionGiftEventModel model;

  const TwitchSubscriptionGiftEventWidget(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return DecoratedEventWidget.icon(
      icon: Icons.redeem,
      child: StyledText(
        text: AppLocalizations.of(context)!.subscriptionGiftEvent(
            model.gifterUserName,
            model.total,
            model.tier.replaceAll("000", ""),
            model.cumulativeTotal),
        tags: {
          'b': StyledTextTag(style: Theme.of(context).textTheme.titleSmall),
        },
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: tierColor(context, model.tier)),
      ),
    );
  }
}

class TwitchSubscriptionMessageEventWidget extends StatelessWidget {
  final TwitchSubscriptionMessageEventModel model;

  const TwitchSubscriptionMessageEventWidget(this.model, {super.key});

  Iterable<InlineSpan> _render(
      BuildContext context, StyleModel styleModel, MessageToken token) sync* {
    final tagStyleStreamer = TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.black,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white);
    //for streamermention

    final tagStyle = TextStyle(
        backgroundColor: Theme.of(context).highlightColor); //for usermention

    if (token is TextToken) {
      yield TextSpan(text: token.text);
    } else if (token is EmoteToken) {
      yield WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Tooltip(
              message: token.code,
              preferBelow: false,
              child: Image(
                  height: styleModel.fontSize,
                  image: ResilientNetworkImage(token.url),
                  errorBuilder: (context, error, stackTrace) =>
                      Text(token.code))));
    } else if (token is UserMentionToken) {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final loginChannel = userModel.userChannel?.displayName;
      if (token.username.toLowerCase() == loginChannel?.toLowerCase()) {
        yield TextSpan(
            // wrap tag with nonbreaking spaces
            text: "\u{00A0}@${token.username}\u{00A0}",
            style: tagStyleStreamer);
      } else {
        yield TextSpan(
            // wrap tag with nonbreaking spaces
            text: "\u{00A0}@${token.username}\u{00A0}",
            style: tagStyle);
      }
    } else {
      throw Exception("invalid token");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.titleSmall;
    return DecoratedEventWidget.icon(
      icon: Icons.star,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StyledText(
          text: AppLocalizations.of(context)!.subscriptionMessageEvent(
            model.subscriberUserName,
            model.cumulativeMonths,
            model.tier.replaceAll("000", ""),
          ),
          tags: {
            'b': StyledTextTag(style: Theme.of(context).textTheme.titleSmall),
          },
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: tierColor(context, model.tier)),
        ),
        if (model.text.isNotEmpty)
          Consumer<StyleModel>(builder: (context, styleModel, child) {
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: model.subscriberUserName, style: textTheme),
                  const TextSpan(text: ": "),
                  ...model.tokenize().expand((token) {
                    return _render(context, styleModel, token);
                  }),
                ],
              ),
            );
          }),
      ]),
    );
  }
}
