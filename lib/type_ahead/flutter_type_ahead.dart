import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class SuggestedDataWrapper<T> {
  ///You can use this to store additional data e.g UserModel
  final T? item;

  ///Important, this will define how the controller will call out your item;
  final String prefix;

  ///Check with data
  final String id;

  final String text;

  SuggestedDataWrapper(
      {required this.id, required this.prefix, this.item, required this.text});

  @override
  bool operator ==(Object other) {
    return other is SuggestedDataWrapper &&
        other.prefix == this.prefix &&
        other.id == this.id;
  }

  int get hashCode => super.hashCode;
}

class TypeAheadTextFieldController<T> extends TextEditingController {
  ///set this scroll controller to TextField constructor to translate the suggestion dialog base on scroll controller offset
  final ScrollController scrollController = new ScrollController();
  OnRemovingMatchedTextAction _onRemovingMatchedTextAction =
      OnRemovingMatchedTextAction.nothing;

  OnRemovingMatchedTextAction get onRemovingMatchedTextAction =>
      _onRemovingMatchedTextAction;

  bool isDeleting = false;
  String? lastText;

  ///the TextField Key, of course
  late final GlobalKey<EditableTextState> textFieldKey;

  ///which prefixes you want to catch, support multiple prefixes e.g @, #, &, ...
  late Set<String> appliedPrefixes;

  ///regex to check text field text and split to highlight the approved parts
  late RegExp _allRegex;

  ///padding to the suggestion dialog
  final EdgeInsets? edgePadding;

  ///called when match or non match the prefix
  Function(PrefixMatchState? prefixMatchState)? onStateChanged;

  String Function(PrefixMatchState? prefixMatchState)? onStateChange;

  ///set a list of suggestion based on the matching prefix, you can change it later, make sure to call setState
  Set<SuggestedDataWrapper<T>>? _suggestibleData;

  ///custom span for matching text
  TextSpan Function(SuggestedDataWrapper<T> data)? customSpanBuilder;

  ///call when a matching text get removed
  Function(List<SuggestedDataWrapper<T>> data)? onRemove;

  final BehaviorSubject<PrefixMatchState?> _bhMatchedState =
      BehaviorSubject.seeded(null);

  final BehaviorSubject<List<SuggestedDataWrapper<T>>?>
      _bhMatchedSuggestionList = BehaviorSubject.seeded(null);

  ValueStream<PrefixMatchState?> get matchStateStream => _bhMatchedState.stream;

  PrefixMatchState? get currentMatchState => _bhMatchedState.value;

  ValueStream<List<SuggestedDataWrapper<T>>?> get matchedSuggestionListStream =>
      _bhMatchedSuggestionList.stream;

  late final StreamSubscription<PrefixMatchState?> _subscription;

  TypeAheadTextFieldController(
      {required this.appliedPrefixes,
      required this.textFieldKey,
      this.customSpanBuilder,
      this.onRemove,
      this.edgePadding =
          const EdgeInsets.only(left: 8, right: 0, top: 20, bottom: 0),
      this.onStateChanged,
      Set<SuggestedDataWrapper<T>>? suggestibleData}) {
    this._suggestibleData = suggestibleData;
    _subscription = _bhMatchedState.listen((value) {
      _notifySuggestions();
    });
  }

  Set<String>? _prefixes;
  double? _scrollOffset;
  double? devicePixelRatio;
  Set<SuggestedDataWrapper<T>> _approvedData = Set();
  String? _lastCheckedText;
  late double _cursorHeight;
  late double _cursorWidth;

  @override
  TextSpan buildTextSpan(
      {BuildContext? context, TextStyle? style, bool? withComposing}) {
    List<TextSpan> children = [];
    List<SuggestedDataWrapper> tempMatchedList = [];
    isDeleting = lastText != null && lastText!.length > text.length;
    if (_suggestibleData != null && _approvedData.isNotEmpty) {
      _prefixes = appliedPrefixes;

      List<String> patterns = [];

      _prefixes!.forEach((e) {
        var matchedWithPrefix = _approvedData
            .where((element) => element.prefix == e)
            .map((e) => e.text)
            .toSet();
        if (matchedWithPrefix.length > 0) {
          patterns.add(r'(?<=' +
              e +
              ')(' +
              '${matchedWithPrefix.map((e) => '$e').join('|')}' +
              r')');
        }
      });

      var patternStr = patterns.join('|');
      //print('patternStr -- $patternStr');
      _allRegex = RegExp(patternStr);
      text.splitMapJoin(_allRegex, onMatch: (s) {
        String itemText = text.trim().substring(s.start, s.end);
        //print('on match -- $itemText');
        String prefix = text.substring(s.start - 1, s.start);
        SuggestedDataWrapper<T>? data;
        try {
          data = _approvedData.length > 0
              ? _approvedData.firstWhere(
                  (data) => data.text == itemText && prefix == prefix,
                )
              : null;
        } catch (e) {}
        var span = (this.customSpanBuilder != null && data != null)
            ? customSpanBuilder!(data)
            : TextSpan(
                text: itemText,
                style: style,
              );
        //print('add text -- $itemText - $data');
        children.add(span);

        if (data != null) {
          tempMatchedList.add(data);
        }

        int? singleOffset;

        if (selection.baseOffset == selection.extentOffset) {
          singleOffset = selection.baseOffset;
        }

        if (isDeleting && singleOffset != null && singleOffset == s.end) {
          /// Decide what to do next when user deleting then reach the end of the matched text

          switch (_onRemovingMatchedTextAction) {
            case OnRemovingMatchedTextAction.selectAll:

              /// As [OnRemovingMatchedTextAction] is set to [OnRemovingMatchedTextAction.selectAll]
              ///select all matched word if user deleted the character next to the matched word

              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                selection = TextSelection(
                    baseOffset: s.start,
                    extentOffset: s.end,
                    affinity: TextAffinity.downstream,
                    isDirectional: false);
              });
              break;
            case OnRemovingMatchedTextAction.removeAll:

              /// As [OnRemovingMatchedTextAction] is set to [OnRemovingMatchedTextAction.removeAll]
              /// remove all matched word if user deleted the character next to the matched word
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                text = text.replaceRange(s.start, s.end, '');
              });
              break;
            case OnRemovingMatchedTextAction.nothing:

              /// do nothing

              break;
          }
        }
        return text;
      }, onNonMatch: (s) {
        children.add(
          TextSpan(text: s),
        );
        return s;
      });
    } else {
      children.add(TextSpan(text: text, style: style));
    }

    var deletedWords = _approvedData.where((element) {
      return !tempMatchedList.contains(element);
    }).toList();

    if (deletedWords.length > 0) {
      onRemove?.call(deletedWords);
      deletedWords.forEach((element) {
        _approvedData.remove(element);
      });
    }

    if (_lastCheckedText == null || _lastCheckedText != text) {
      try {
        TextPainter painter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(text: '', children: children),
        );
        try {
          painter.layout();
        } catch (e) {}

        var textField = (textFieldKey.currentWidget as TextField?);
        if (textField is TextField) {
          _cursorWidth = textField.cursorWidth;
          _cursorHeight =
              ((textFieldKey.currentWidget as TextField).cursorHeight ??
                  style?.fontSize ??
                  Theme.of(textFieldKey.currentContext!)
                      .textTheme
                      .bodySmall!
                      .fontSize!);

          if (devicePixelRatio == null && textFieldKey.currentContext != null) {
            devicePixelRatio =
                MediaQuery.of(textFieldKey.currentContext!).devicePixelRatio;
          }

          Rect caretPrototype =
              Rect.fromLTWH(0.0, 0.0, _cursorWidth, _cursorHeight);

          TextPosition cursorTextPosition = this.selection.base;

          Offset caretOffset =
              painter.getOffsetForCaret(cursorTextPosition, caretPrototype);

          var preferredLineHeight = painter.preferredLineHeight;

          Offset positiveOffset = Offset(
            caretOffset.dx > 0 ? caretOffset.dx : -caretOffset.dx,
            (caretOffset.dy > 0 ? caretOffset.dy : -caretOffset.dy) +
                preferredLineHeight,
          );
          print('isDeleting - $isDeleting');
          _selectionCheck(positiveOffset, _cursorHeight, isDeleting);
        }
      } catch (e) {
        throw e;
      }
    }

    _lastCheckedText = text;
    lastText = text;
    return TextSpan(style: style, children: children);
  }

  setApprovedData(Set<SuggestedDataWrapper<T>> data) {
    this._suggestibleData = data;
    _notifySuggestions();
  }

  void approveSelection(PrefixMatchState state, SuggestedDataWrapper<T> data) {
    _approvedData.add(data);
    TextSelection selection = this.selection;

    int position = selection.baseOffset;

    int replacedLength = state.text.replaceAll('${state.prefix}', '').length;

    String newText = this
        .text
        .replaceRange(position - replacedLength, position, data.text + ' ');

    text = newText;

    int offset = position + (data.text.length - replacedLength);

    selection = TextSelection.fromPosition(TextPosition(offset: offset + 1));
    _lastCheckedText = newText;

    this.selection = selection;
  }

  void _selectionCheck(
      Offset dimensionalOffset, double cursorHeight, bool isDeleting) {
    try {
      if (selection.start > 0) {
        List<String> texts = text.substring(0, selection.start).split(' ');
        if (texts.length > 0) {
          var lines =
              '\n'.allMatches(text.substring(0, selection.baseOffset)).length +
                  1;

          ///r'(?!(\r\n|\n|\r)).*'

          var str =
              appliedPrefixes.map((prefix) => r'(' + prefix + '.*)').join('|');

          str = '^($str)' + r'(?!(\r\n|\n|\r))$';

          var generalRegexp = RegExp(str);

          if (generalRegexp.hasMatch(texts.last)) {
            String prefix = '';
            appliedPrefixes.forEach((element) {
              if (texts.last.startsWith(element)) {
                prefix = element;
              }
            });

            if (scrollController.hasClients) {
              if (scrollController.position.axis == Axis.horizontal) {
                _scrollOffset =
                    this.scrollController.position.pixels / devicePixelRatio!;
              } else {
                _scrollOffset = this.scrollController.position.pixels;
              }
            } else {
              _scrollOffset = 0.0;
            }

            double physicalOffsetDx = dimensionalOffset.dx;

            double physicalOffsetDy = lines * (cursorHeight + 5) + 12;

            if (_scrollOffset != null && _scrollOffset! >= 0) {
              if (scrollController.position.axis == Axis.horizontal) {
                physicalOffsetDx = physicalOffsetDx - (_scrollOffset ?? 0);
              } else {
                physicalOffsetDy = physicalOffsetDy - (_scrollOffset ?? 0);
              }
            }

            Offset physicalOffset = new Offset(
                physicalOffsetDx + (edgePadding?.left ?? 0), physicalOffsetDy);

            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              final state =
                  PrefixMatchState(prefix, texts.last, physicalOffset);
              if (!isDeleting) {
                onStateChanged?.call(state);
                _bhMatchedState.add(state);
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              onStateChanged?.call(null);
            });
          }
        }
      }
    } catch (e) {
      //print(e);
    }
  }

  Set<SuggestedDataWrapper<T>> getApprovedData() => _approvedData;

  Offset? calculateGlobalOffset(
      {required BuildContext context,
      required Offset localOffset,
      required Size overlayContainerSize}) {
    RenderBox? tfBox =
        textFieldKey.currentContext?.findRenderObject() as RenderBox?;

    final position = tfBox?.localToGlobal(Offset.zero);
    if (position == null) return null;
    double? screenWidth = MediaQuery.of(context).size.width;
    double? screenHeight = MediaQuery.of(context).size.height;

    return getPosition(Rect.fromLTWH(0, 0, screenWidth, screenHeight),
        overlayContainerSize, localOffset + position);
  }

  Offset? getPosition(Rect rectA, Size sizeB, Offset offset) {
    // Possible positions relative to the offset
    double maxLeft = rectA.width - sizeB.width - 1;
    //double maxTop = rectA.height - sizeB.height - 1;
    final rects = {
      TypeAheadAlignEnum.bottomLeft: Rect.fromLTWH(
          offset.dx - sizeB.width, offset.dy, sizeB.width, sizeB.height),
      TypeAheadAlignEnum.bottomRight:
          Rect.fromLTWH(offset.dx, offset.dy, sizeB.width, sizeB.height),
      TypeAheadAlignEnum.topLeft: Rect.fromLTWH(offset.dx - sizeB.width,
          offset.dy - sizeB.height, sizeB.width, sizeB.height),
      TypeAheadAlignEnum.topRight: Rect.fromLTWH(
          offset.dx, offset.dy - sizeB.height, sizeB.width, sizeB.height),
    };

    // Check for truncation and return the first valid position
    for (var rect in rects.entries) {
      final safeRect = Rect.fromLTWH(min(maxLeft, rect.value.left),
          rect.value.top, rect.value.width, rect.value.height);
      if (_isRectInside(rectA, safeRect)) {
        return safeRect.topLeft;
      }
    }
    return null;
  }

  bool _isRectInside(Rect outer, Rect inner) {
    return outer.contains(inner.topLeft) &&
        outer.contains(inner.topRight) &&
        outer.contains(inner.bottomLeft) &&
        outer.contains(inner.bottomRight);
  }

  void _notifySuggestions() {
    _bhMatchedSuggestionList.add(_suggestibleData
        ?.where((element) => element.prefix == _bhMatchedState.value?.prefix)
        .toList());
  }

  void setOnRemovingMatchedTextAction(OnRemovingMatchedTextAction action) {
    _onRemovingMatchedTextAction = action;
  }

  @override
  void dispose() {
    _bhMatchedState.close();
    _bhMatchedSuggestionList.close();
    _subscription.cancel();
    super.dispose();
  }
}

enum TypeAheadAlignEnum { topLeft, topRight, bottomLeft, bottomRight }

class PrefixMatchState {
  final String prefix;
  final String text;

  get baseText => text.replaceFirst(prefix, '');
  final Offset offset;

  PrefixMatchState(this.prefix, this.text, this.offset);
}

enum OnRemovingMatchedTextAction {
  nothing,
  selectAll,
  removeAll,
}
