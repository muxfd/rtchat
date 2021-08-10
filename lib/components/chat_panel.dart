import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/chat_history/message.dart';
import 'package:rtchat/components/pinnable/scroll_view.dart';
import 'package:rtchat/models/channels.dart';
import 'package:rtchat/models/chat_history.dart';
import 'package:rtchat/models/messages/message.dart';
import 'package:rxdart/rxdart.dart';

class ChatPanelWidget extends StatefulWidget {
  final void Function(bool)? onScrollback;

  const ChatPanelWidget({Key? key, this.onScrollback}) : super(key: key);

  @override
  _ChatPanelWidgetState createState() => _ChatPanelWidgetState();
}

class _ChatPanelWidgetState extends State<ChatPanelWidget>
    with TickerProviderStateMixin {
  final _controller = ScrollController(keepScrollOffset: true);
  var _atBottom = true;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final value = _controller.position.atEdge && _controller.offset == 0;
      if (_atBottom != value) {
        setState(() {
          _atBottom = value;
        });
        if (widget.onScrollback != null) {
          widget.onScrollback!(!_atBottom);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Consumer<ChannelsModel>(builder: (context, model, child) {
        return StreamBuilder<List<MessageModel>>(
            stream: model.chatHistory.scan((acc, event, i) {
              if (event is AppendDeltaEvent) {
                acc.add(event.model);
              } else if (event is UpdateDeltaEvent) {
                for (var i = 0; i < acc.length; i++) {
                  if (acc[i].messageId == event.messageId) {
                    acc[i] = event.update(acc[i]);
                  }
                }
              }
              return acc;
            }, []),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) {
                return Container();
              }
              final messages = data.reversed.toList();
              return PinnableMessageScrollView(
                vsync: this,
                controller: _controller,
                itemBuilder: (index) =>
                    ChatHistoryMessage(message: messages[index]),
                isPinnedBuilder: (index) => messages[index].pinned,
                count: messages.length,
              );
            });
      }),
      Builder(builder: (context) {
        if (_atBottom) {
          return Container();
        }
        return Container(
          alignment: Alignment.bottomCenter,
          child: TextButton(
              onPressed: () {
                _controller.animateTo(0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut);
              },
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all(Colors.black.withOpacity(0.6)),
                padding: MaterialStateProperty.all(
                    const EdgeInsets.only(left: 16, right: 16)),
              ),
              child: const Text("Scroll to bottom")),
        );
      }),
    ]);
  }
}
