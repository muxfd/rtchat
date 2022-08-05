import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/emote_picker.dart';
import 'package:rtchat/models/adapters/actions.dart';
import 'package:rtchat/models/channels.dart';
import 'package:rtchat/models/chat_mode.dart';
import 'package:rtchat/models/commands.dart';

class MessageInputWidget extends StatefulWidget {
  final Channel channel;

  const MessageInputWidget({Key? key, required this.channel}) : super(key: key);

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget> {
  final _textEditingController = TextEditingController();
  final _chatInputFocusNode = FocusNode();
  var _isEmotePickerVisible = false;
  late StreamSubscription<bool> keyboardSubscription;

  OverlayEntry? entry;

  @override
  void initState() {
    super.initState();
    var keyboardVisibilityController = KeyboardVisibilityController();
    // Subscribe to keyboard visibility changes.
    keyboardSubscription =
        keyboardVisibilityController.onChange.listen((bool visible) async {
      print('Keyboard visibility update. Is visible: $visible');
      if (visible && _textEditingController.text.isEmpty) {
        /*
            this is a hack to position the overlay.
            the overlay uses the message textfield to determine the position
            of the overlay, so we need to wait for the keyboard to show
          */
        await Future.delayed(const Duration(milliseconds: 650));
        showOverlay("", CommandType.exclamation);
      } else {
        hideOverlay();
      }
    });
  }

  bool startsWithsExlamination(String text) {
    if (text == "" || text.isEmpty) {
      return false;
    }
    final exclaimationList =
        Provider.of<CommandsModel>(context, listen: false).commandList;
    final hasExclaimation = exclaimationList.any((command) =>
        command.command.startsWith(text) ||
        command.command.toLowerCase().startsWith(text));
    return hasExclaimation;
  }

  bool startsWithPossibleCommands(String text) {
    if (text == "" || text.isEmpty) {
      return false;
    }
    final hasSlash =
        ChatMode.values.any((element) => element.title.startsWith(text));
    return hasSlash;
  }

  Widget commandChips() {
    final model = Provider.of<CommandsModel>(context, listen: false);
    final commands = model.commandList;

    return SizedBox(
      height: 300.0,
      child: Wrap(
        direction: Axis.horizontal,
        children: [
          for (var command in commands)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: ActionChip(
                backgroundColor: Color.fromARGB(255, 65, 172, 79),
                label: Text(command.command),
                onPressed: () {
                  ActionsAdapter.instance.send(widget.channel, command.command);

                  model.addCommand(Command(command.command, DateTime.now()));
                  _chatInputFocusNode.unfocus();
                  hideOverlay();
                },
              ),
            ),
        ],
      ),
    );
  }

  void hideOverlay() {
    entry?.remove();
    entry = null;
  }

  void showOverlay(String text, CommandType type) {
    // remove existing overlay, bc user can contiunously type a prefix string that matches a command
    hideOverlay();

    final overlay = Overlay.of(context)!;

    // the renderbox of this widget
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final offset = renderBox.localToGlobal(Offset.zero);
    final lst =
        ChatMode.values.where((element) => element.title.startsWith(text));

    final commands = lst.map((e) {
      return ListTile(
        title: Text(e.title),
        subtitle: Text(e.subtitle),
        onTap: () {
          _textEditingController.text = e.title;
          hideOverlay();
          // move cursor position
          _textEditingController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textEditingController.text.length));
        },
      );
    }).toList();

    // None to show
    if (commands.isEmpty) {
      hideOverlay();
      return;
    }

    final lstSize = commands.length;
    const listTileSize = 75; // the roughly size of a listTile
    final shiftUp = min(lstSize * listTileSize, 300);

    entry = OverlayEntry(builder: (context) {
      return Positioned(
        left: offset.dx,
        top: offset.dy - shiftUp,
        width: size.width,
        child: Material(
          child: type == CommandType.exclamation
              ? commandChips()
              : SizedBox(
                  height: shiftUp.toDouble(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    primary: false,
                    children: commands,
                  ),
                ),
        ),
      );
    });

    overlay.insert(entry!);
  }

  void sendMessage(String value) async {
    value = value.trim();
    if (value.isEmpty) {
      return;
    }
    if (value.startsWith('!')) {
      final commandsModel = Provider.of<CommandsModel>(context, listen: false);
      commandsModel.addCommand(Command(value, DateTime.now()));
    }
    ActionsAdapter.instance.send(widget.channel, value);
    _textEditingController.clear();
  }

  // Widget _buildCommandBar(BuildContext context) {
  //   return KeyboardVisibilityBuilder(builder: (context, isKeyboardVisible) {
  //     final commandsModel = Provider.of<CommandsModel>(context, listen: false);
  //     if (!isKeyboardVisible || commandsModel.commandList.isEmpty) {
  //       return Container();
  //     }

  //     return Padding(
  //       child: Container(
  //         height: 222,
  //         width: 222,
  //         color: Colors.blue,
  //         margin: EdgeInsets.only(bottom: 500),
  //       ),
  //       padding: EdgeInsets.only(bottom: isKeyboardVisible ? 50 : 0),
  //     );
  //   });
  // }

  Widget _buildEmotePicker(BuildContext context) {
    return EmotePickerWidget(
        channelId: widget.channel.channelId,
        onDismiss: () => setState(() => _isEmotePickerVisible = false),
        onDelete: () {
          var initialText = _textEditingController.text;
          if (initialText.isNotEmpty) {
            _textEditingController.text =
                initialText.substring(0, initialText.length - 1);
          }
        },
        onEmoteSelected: (emote) {
          _textEditingController.text =
              "${_textEditingController.text} ${emote.code}";
        });
  }

  @override
  Widget build(BuildContext context) {
    // remove overlay if keyboard is not visible
    // if (MediaQuery.of(context).viewInsets.bottom == 0) {
    //   hideOverlay();
    // }

    return Material(
      child: Column(children: [
        // (_textEditingController.text.isEmpty
        //     ? _buildCommandBar(context)
        //     : const SizedBox(height: 0, width: 0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                color: Theme.of(context).inputDecorationTheme.fillColor),
            child: Row(children: [
              Expanded(
                child: TextField(
                  focusNode: _chatInputFocusNode,
                  controller: _textEditingController,
                  textInputAction: TextInputAction.send,
                  maxLines: 6,
                  minLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                      prefixIcon: Material(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(24),
                        child: IconButton(
                            color: Theme.of(context).colorScheme.onSurface,
                            onPressed: () {
                              hideOverlay();
                              if (_isEmotePickerVisible) {
                                setState(() => _isEmotePickerVisible = false);
                                _chatInputFocusNode.requestFocus();
                              } else {
                                _chatInputFocusNode.unfocus();
                                setState(() => _isEmotePickerVisible = true);
                              }
                            },
                            splashRadius: 24,
                            icon: Icon(_isEmotePickerVisible
                                ? Icons.keyboard_rounded
                                : Icons.tag_faces_rounded)),
                      ),
                      suffixIcon: Material(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(24),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded),
                          color: Theme.of(context).colorScheme.primary,
                          splashRadius: 24,
                          onPressed: () =>
                              sendMessage(_textEditingController.text),
                        ),
                      ),
                      border: InputBorder.none,
                      hintText: "Send a message..."),
                  onChanged: (text) {
                    // slash prefix
                    if (startsWithPossibleCommands(text)) {
                      showOverlay(text, CommandType.slash);
                    } else {
                      hideOverlay();
                      // showOverlay("", CommandType.exclamation);
                    }

                    final filtered = text.replaceAll('\n', ' ');
                    if (filtered == text) {
                      return;
                    }
                    _textEditingController.value = TextEditingValue(
                        text: filtered,
                        selection: TextSelection.fromPosition(TextPosition(
                            offset: _textEditingController.text.length)));
                  },
                  onSubmitted: sendMessage,
                  onTap: () async {
                    // if (_textEditingController.text.isEmpty) {
                    //   /*
                    //     this is a hack to position the overlay.
                    //     the overlay uses the message textfield to determine the position
                    //     of the overlay, so we need to wait for the keyboard to show
                    //   */
                    //   await Future.delayed(const Duration(milliseconds: 1000));
                    //   showOverlay("", CommandType.exclamation);
                    // }
                    setState(() => _isEmotePickerVisible = false);
                    _chatInputFocusNode.requestFocus();
                  },
                ),
              ),
            ]),
          ),
        ),
        // (_textEditingController.text.isEmpty
        //     ? _buildCommandBar(context)
        //     : const SizedBox(height: 0, width: 0)),
        _isEmotePickerVisible ? _buildEmotePicker(context) : Container(),
      ]),
    );
  }
}

enum CommandType {
  slash,
  exclamation,
}
