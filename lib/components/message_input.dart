import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/autocomplete.dart';
import 'package:rtchat/components/emote_picker.dart';
import 'package:rtchat/components/image/resilient_network_image.dart';
import 'package:rtchat/models/adapters/actions.dart';
import 'package:rtchat/models/channels.dart';
import 'package:rtchat/models/commands.dart';
import 'package:rtchat/models/messages/tokens.dart';
import 'package:rtchat/models/messages/twitch/emote.dart';
import 'package:rtchat/models/style.dart';
import 'package:rtchat/share_channel.dart';

class EmoteTextEditingController extends TextEditingController {
  List<Emote> emotes;

  EmoteTextEditingController(this.emotes);

  Iterable<MessageToken> tokenizeEmotes(
      String message, List<Emote> emotes) sync* {
    final emotesMap = {for (final emote in emotes) emote.code: emote};
    var lastParsedStart = 0;
    for (var start = 0; start < message.length;) {
      final end = message.indexOf(" ", start);
      final token =
          end == -1 ? message.substring(start) : message.substring(start, end);
      final emote = emotesMap[token.trim()];
      if (emote != null) {
        if (lastParsedStart != start) {
          yield TextToken(message.substring(lastParsedStart, start));
        }
        yield EmoteToken(url: emote.uri, code: emote.code);
        lastParsedStart = end == -1 ? message.length : end;
      }
      start = end == -1 ? message.length : end + 1;
    }
    if (lastParsedStart != message.length) {
      yield TextToken(message.substring(lastParsedStart));
    }
  }

  static Iterable<InlineSpan> render(
      BuildContext context, StyleModel styleModel, MessageToken token) sync* {
    if (token is TextToken) {
      yield TextSpan(text: token.text);
    } else if (token is EmoteToken) {
      yield* [
        TextSpan(text: "\u200B" * (token.code.length - 1)),
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
                message: token.code,
                preferBelow: false,
                child: Image(
                    height: styleModel.fontSize,
                    image: ResilientNetworkImage(token.url),
                    errorBuilder: (context, error, stackTrace) =>
                        Text(token.code))))
      ];
    } else {
      throw Exception("invalid token");
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(!value.composing.isValid ||
        !withComposing ||
        value.isComposingRangeValid);
    // If the composing range is out of range for the current text, ignore it to
    // preserve the tree integrity, otherwise in release mode a RangeError will
    // be thrown and this EditableText will be built with a broken subtree.
    final bool composingRegionOutOfRange =
        !value.isComposingRangeValid || !withComposing;

    final styleModel = Provider.of<StyleModel>(context, listen: false);

    if (composingRegionOutOfRange) {
      return TextSpan(
          style: style,
          children: tokenizeEmotes(text, emotes)
              .expand((token) => render(context, styleModel, token))
              .toList());
    }

    final TextStyle composingStyle =
        style?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
            const TextStyle(decoration: TextDecoration.underline);

    return TextSpan(
      style: style,
      children: <TextSpan>[
        TextSpan(
            children:
                tokenizeEmotes(value.composing.textBefore(value.text), emotes)
                    .expand((token) => render(context, styleModel, token))
                    .toList()),
        TextSpan(
          style: composingStyle,
          text: value.composing.textInside(value.text),
        ),
        TextSpan(
            children:
                tokenizeEmotes(value.composing.textAfter(value.text), emotes)
                    .expand((token) => render(context, styleModel, token))
                    .toList()),
      ],
    );
  }
}

class MessageInputWidget extends StatefulWidget {
  final Channel channel;
  final List<Emote> emotes; // TODO: decouple this from the twitch emote model.

  const MessageInputWidget({
    super.key,
    required this.channel,
    required this.emotes,
  });

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

final _emotes = [
  "https://static-cdn.jtvnw.net/emoticons/v2/425618/default/light/2.0",
  "https://static-cdn.jtvnw.net/emoticons/v2/112291/default/light/2.0",
  "https://static-cdn.jtvnw.net/emoticons/v2/81274/default/light/2.0",
  "https://static-cdn.jtvnw.net/emoticons/v2/28087/default/light/2.0",
  "https://static-cdn.jtvnw.net/emoticons/v2/305954156/default/light/2.0",
];

const _greyscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, // red
  0.2126, 0.7152, 0.0722, 0, 0, // green
  0.2126, 0.7152, 0.0722, 0, 0, // blue
  0, 0, 0, 1, 0, // alpha
]);

class _MessageInputWidgetState extends State<MessageInputWidget> {
  EmoteTextEditingController? _textEditingController;
  final _chatInputFocusNode = FocusNode();
  var _isEmotePickerVisible = false;
  var _isKeyboardVisible = false;
  late StreamSubscription keyboardSubscription;
  var _emoteIndex = Random().nextInt(_emotes.length);
  final _textSeed = Random().nextDouble();
  final List<String> _pendingSend = [];

  @override
  void initState() {
    super.initState();
    final keyboardVisibilityController = KeyboardVisibilityController();
    _textEditingController = EmoteTextEditingController(widget.emotes);
    // Subscribe to keyboard visibility changes.
    keyboardSubscription =
        keyboardVisibilityController.onChange.listen((visible) {
      setState(() {
        _isKeyboardVisible = visible;
      });
    });

    ShareChannel()
      // Register a callback to handle any shared data while app is running
      ..onDataReceived = _handleSharedData
      // Check to see if there is any shared data already via sharing
      ..getSharedText().then(_handleSharedData);
  }

  @override
  void didUpdateWidget(MessageInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _textEditingController?.emotes = widget.emotes;
  }

  // Handles any shared data we may receive.
  void _handleSharedData(String sharedData) {
    setState(() {
      _textEditingController?.text = sharedData;
    });
  }

  @override
  void dispose() {
    keyboardSubscription.cancel();
    _chatInputFocusNode.dispose();
    _textEditingController?.dispose();
    super.dispose();
  }

  void sendMessage(String value) async {
    value = value.trim();
    if (value.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (value.startsWith('!')) {
      final commandsModel = Provider.of<CommandsModel>(context, listen: false);
      commandsModel.addCommand(Command(value, DateTime.now()));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _textEditingController?.clear();
    });
    var done = false;
    await Future.wait([
      () async {
        try {
          final error =
              await ActionsAdapter.instance.send(widget.channel, value);
          if (error != null) {
            messenger.showSnackBar(SnackBar(
              content: Text(error),
            ));
          }
        } catch (e) {
          messenger.showSnackBar(SnackBar(
            content: Text(e.toString()),
          ));
        }
        done = true;
        if (!mounted) {
          return;
        }
        setState(() {
          _pendingSend.remove(value);
        });
      }(),
      () async {
        await Future.delayed(const Duration(seconds: 1));
        if (!done) {
          if (!mounted) {
            return;
          }
          setState(() {
            _pendingSend.add(value);
          });
        }
      }(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // render pending sends
            ..._pendingSend.map((e) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Text(e,
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                )),
            if (_isKeyboardVisible)
              Flexible(
                child: AutocompleteWidget(
                  controller: _textEditingController!,
                  onSend: sendMessage,
                  channel: widget.channel,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                    color: Theme.of(context).splashColor),
                child: TextField(
                  focusNode: _chatInputFocusNode,
                  controller: _textEditingController,
                  textInputAction: TextInputAction.send,
                  maxLines: 6,
                  minLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                      prefixIcon: IconButton(
                        onPressed: () {
                          if (_isEmotePickerVisible) {
                            setState(() => _isEmotePickerVisible = false);
                            _chatInputFocusNode.requestFocus();
                          } else {
                            _chatInputFocusNode.unfocus();
                            setState(() {
                              _isEmotePickerVisible = true;
                              _emoteIndex = Random().nextInt(_emotes.length);
                            });
                          }
                        },
                        splashRadius: 24,
                        icon: _isEmotePickerVisible
                            ? const Icon(Icons.keyboard_rounded)
                            : ColorFiltered(
                                colorFilter: _greyscale,
                                child: Image(
                                  width: 24,
                                  height: 24,
                                  image: ResilientNetworkImage(
                                      Uri.parse(_emotes[_emoteIndex])),
                                )),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Theme.of(context).colorScheme.primary,
                        splashRadius: 24,
                        onPressed: () =>
                            sendMessage(_textEditingController?.text ?? ''),
                      ),
                      border: InputBorder.none,
                      hintMaxLines: 1,
                      hintText: () {
                        final l10n = AppLocalizations.of(context)!;
                        if (_textSeed < 0.5) {
                          return l10n.sendAMessage;
                        } else if (_textSeed < 0.9) {
                          return l10n.writeSomething;
                        } else if (_textSeed < 0.99) {
                          return l10n.speakToTheCrowds;
                        } else if (_textSeed < 0.999) {
                          return l10n.shareYourThoughts;
                        }
                        return l10n.saySomethingYouLittleBitch;
                      }()),
                  onChanged: (text) {
                    final filtered = text.replaceAll('\n', ' ');
                    if (filtered == text) {
                      return;
                    }
                    setState(() {
                      _textEditingController?.value = TextEditingValue(
                          text: filtered,
                          selection: TextSelection.fromPosition(TextPosition(
                              offset: _textEditingController?.text.length ??
                                  0)));
                    });
                  },
                  onSubmitted: sendMessage,
                  onTap: () {
                    setState(() => _isEmotePickerVisible = false);
                    _chatInputFocusNode.requestFocus();
                  },
                ),
              ),
            ),
            _isEmotePickerVisible
                ? EmotePickerWidget(
                    channel: widget.channel,
                    emotes: widget.emotes,
                    onEmoteSelected: (emote) {
                      if (emote == null) {
                        setState(() {
                          _isEmotePickerVisible = false;
                        });
                        return;
                      }
                      if (_textEditingController?.text.isNotEmpty ?? false) {
                        _textEditingController?.text =
                            "${_textEditingController?.text} ${emote.code} ";
                      } else {
                        _textEditingController?.text = "${emote.code} ";
                      }
                    })
                : Container(),
          ]),
    );
  }
}
