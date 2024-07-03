import 'package:flutter/material.dart';
import 'package:type_ahead_text_field/type_ahead/flutter_type_ahead.dart';

import 'articles_bank.dart';

class ArticlePickerPage extends StatefulWidget {
  const ArticlePickerPage({Key? key}) : super(key: key);

  @override
  State<ArticlePickerPage> createState() => _ArticlePickerPageState();
}

class _ArticlePickerPageState extends State<ArticlePickerPage> {
  OverlayEntry? overlayEntry;

  GlobalKey<EditableTextState> tfKey = GlobalKey();

  PrefixMatchState? filterState;

  GlobalKey suggestionWidgetKey = GlobalKey();

  late final TypeAheadTextFieldController<ArticleData> controller =
      TypeAheadTextFieldController<ArticleData>(
          appliedPrefixes: {'@'},
          textFieldKey: tfKey,
          customSpanBuilder: (SuggestedDataWrapper<ArticleData> data) {
            return TextSpan(
              text: '${data.text}',
              style: TextStyle(color: Colors.blue),
            );
          },
          suggestibleData: generateArticles(),
          onRemove: (data) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              setState(() {});
            });
          },
          onStateChanged: (PrefixMatchState? state) {
            if (state != null &&
                (filterState == null || filterState != state)) {
              filterState = state;
              // matchedState.value = state;
              // bhMatchedState.add(state);
            }

            if (state != null) {
              if (overlayEntry == null) {
                showSuggestionDialog();
              }
            } else {
              removeOverlay();
            }
          });

  @override
  void dispose() {
    overlayEntry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ///a layout with a textfield that allows user to type and select articles, below is the listed of tagged articles
    return Scaffold(
      appBar: AppBar(
        title: Text('Article Picker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Column(
              children: [
                Text('Select action when delete til the last matched text'),
                Row(
                  children: [
                    Radio<OnRemovingMatchedTextAction>(
                      value: OnRemovingMatchedTextAction.removeAll,
                      groupValue: controller.onRemovingMatchedTextAction,
                      onChanged: (value) {
                        controller.setOnRemovingMatchedTextAction(
                            OnRemovingMatchedTextAction.removeAll);
                        setState(() {});
                      },
                    ),
                    Text('Remove last matched text'),
                  ],
                ),
                Row(
                  children: [
                    Radio<OnRemovingMatchedTextAction>(
                      value: OnRemovingMatchedTextAction.selectAll,
                      groupValue: controller.onRemovingMatchedTextAction,
                      onChanged: (value) {
                        controller.setOnRemovingMatchedTextAction(
                            OnRemovingMatchedTextAction.selectAll);
                        setState(() {});
                      },
                    ),
                    Text('Select all'),
                  ],
                ),
                Row(
                  children: [
                    Radio<OnRemovingMatchedTextAction>(
                      value: OnRemovingMatchedTextAction.nothing,
                      groupValue: controller.onRemovingMatchedTextAction,
                      onChanged: (value) {
                        controller.setOnRemovingMatchedTextAction(
                            OnRemovingMatchedTextAction.nothing);
                        setState(() {});
                      },
                    ),
                    Text('Do nothing'),
                  ],
                )
              ],
            ),
            TextField(
              controller: controller,
              scrollController: controller.scrollController,
              key: tfKey,
              decoration: InputDecoration(
                hintText: 'Type @ to select an article',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            StreamBuilder<PrefixMatchState?>(
                stream: controller.matchStateStream,
                builder: (context, snapshot) {
                  if (snapshot.data == null) return Container();
                  return Text('${snapshot.data!.text}');
                }),
            Expanded(
              child: StreamBuilder(
                  stream: controller.matchStateStream,
                  builder: (context, snapshot) {
                    final approvedData = controller.getApprovedData().toList();
                    if (snapshot.data == null)
                      return Center(child: Text('No article selected'));
                    var filteredData = approvedData
                        .where((element) =>
                            element.item != null &&
                            controller.currentMatchState != null &&
                            element.item!.keyword.contains(
                                controller.currentMatchState!.baseText))
                        .toList();
                    return Column(
                      children: [
                        Text(
                            'Selected Articles : ${controller.currentMatchState?.text}'),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredData.length,
                            itemBuilder: (context, index) {
                              var item = filteredData[index];
                              return ListTile(
                                title: Text(item.item!.title),
                                trailing: Text(
                                  '@${item.item!.keyword}',
                                  style: TextStyle(color: Colors.blue),
                                ),
                                subtitle: Text(item.item!.content, maxLines: 1),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ArticlePage(article: item.item!),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }

  showSuggestionDialog() {
    Size size = Size(200, 300);

    overlayEntry = OverlayEntry(builder: (context) {
      return StreamBuilder<PrefixMatchState?>(
          stream: controller.matchStateStream,
          builder: (
            context,
            matchedState,
          ) {
            List<SuggestedDataWrapper<ArticleData>>? filteredData =
                controller.matchedSuggestionListStream.value;

            Offset? offset = matchedState.data == null
                ? null
                : controller.calculateGlobalOffset(
                    context: context,
                    localOffset: matchedState.data!.offset,
                    overlayContainerSize: size);
            return offset != null && filteredData != null
                ? Stack(
                    children: [
                      AnimatedPositioned(
                        key: suggestionWidgetKey,
                        duration: Duration(milliseconds: 250),
                        left: (offset.dx),
                        top: (offset.dy),
                        child: Material(
                          color: Colors.transparent,
                          child: Card(
                            child: Container(
                              height: 300,
                              width: 200,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      child: ListView.builder(
                                        itemBuilder: (context, index) {
                                          var item = filteredData[index];
                                          return GestureDetector(
                                            child: ListTile(
                                              title: Text('${item.text}'),
                                            ),
                                            onTap: () {
                                              controller.approveSelection(
                                                  filterState!, item);
                                              removeOverlay();
                                              setState(() {});
                                            },
                                          );
                                        },
                                        itemCount: filteredData.length,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container();
          });
    });

    Overlay.of(context).insert(overlayEntry!);
  }

  void removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }
}

class ArticlePage extends StatelessWidget {
  final ArticleData article;

  const ArticlePage({Key? key, required this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(article.content),
        ),
      ),
    );
  }
}

class ArticleData {
  final String id;
  final String title;
  final String content;

  final String keyword;

  ArticleData(
      {required this.keyword,
      required this.id,
      required this.title,
      required this.content});
}
