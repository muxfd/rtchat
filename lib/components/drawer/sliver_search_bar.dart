import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/models/drawer/endrawer/viewers_list_model.dart';

class SliverSearchBarWidget extends StatefulWidget {
  const SliverSearchBarWidget({Key? key}) : super(key: key);

  @override
  State<SliverSearchBarWidget> createState() => _SliverSearchBarWidgetState();
}

class _SliverSearchBarWidgetState extends State<SliverSearchBarWidget> {
  @override
  Widget build(BuildContext context) {
    print("searchbar_building");
    final viewersListModel =
        Provider.of<ViewersListModel>(context, listen: false);
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 8),
          child: Center(
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 24.0),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search viewers',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (value) async {
                      print("value is: $value");
                      viewersListModel.filteredByText(value);
                    },
                    // onSubmitted: (value) {
                    //   viewersListModel.filteredByText(value);
                    // },
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
