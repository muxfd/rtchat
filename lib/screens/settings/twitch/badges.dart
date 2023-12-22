import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/image/cross_fade_image.dart';
import 'package:rtchat/components/image/resilient_network_image.dart';
import 'package:rtchat/models/messages/twitch/badge.dart';

class TwitchBadgesScreen extends StatelessWidget {
  const TwitchBadgesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Consumer<TwitchBadgeModel>(builder: (context, model, child) {
        final badges = model.badgeSets;
          badges.sort((a, b) {
            // Check if a or b is "Moderator" or "VIP" and prioritize them.
            const highPriorityBadges = ['Moderator', 'VIP'];
            var titleA = a.versions.last.title;
            var titleB = b.versions.last.title;
            var isAHighPriority = highPriorityBadges.contains(titleA);
            var isBHighPriority = highPriorityBadges.contains(titleB);
            
            if (isAHighPriority && isBHighPriority) {
              return titleA.compareTo(titleB); // If both are high priority, sort alphabetically.
            } else if (isAHighPriority) {
              return -1; // a is high priority, so it comes first.
            } else if (isBHighPriority) {
              return 1; // b is high priority, so it comes first.
            } else {
              return titleA.compareTo(titleB); // Otherwise, sort alphabetically.
            }
          });

          return CustomScrollView(slivers: <Widget>[
            SliverAppBar(
                pinned: true,
                expandedHeight: 250.0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(AppLocalizations.of(context)!.twitchBadges),
                ),
                actions: [
                  Row(children: [
                    Text(AppLocalizations.of(context)!.selectAll),
                    Theme(
                      data: theme.copyWith(
                          unselectedWidgetColor: theme.colorScheme.onTertiary),
                      child: Checkbox.adaptive(
                        tristate: true,
                        value: model.enabledCount == 0
                            ? false
                            : (model.enabledCount == model.badgeCount
                                ? true
                                : null),
                        onChanged: (value) {
                          model.setAllEnabled(value ?? false);
                        },
                      ),
                    )
                  ]),
                ]),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final badge = badges[index];
                  final lastVersion = badge.versions.last;
                  final image =
                      ResilientNetworkImage(Uri.parse(lastVersion.imageUrl4x));
                  return CheckboxListTile.adaptive(
                      secondary: CrossFadeImage(
                          alignment: Alignment.center,
                          placeholder: image.placeholderImage,
                          image: image,
                          height: 36),
                      title: Text(lastVersion.title,
                          overflow: TextOverflow.ellipsis),
                      subtitle: lastVersion.description == lastVersion.title ||
                              lastVersion.description.trim().isEmpty
                          ? null
                          : Text(lastVersion.description,
                              overflow: TextOverflow.ellipsis),
                      value: model.isEnabled(badge.setId),
                      onChanged: (value) {
                        model.setEnabled(badge.setId, value ?? false);
                      });
                },
                childCount: badges.length,
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
