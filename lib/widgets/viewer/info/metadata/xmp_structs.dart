import 'dart:math';

import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/utils/constants.dart';
import 'package:aves/widgets/common/basic/multi_cross_fader.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/highlight_title.dart';
import 'package:aves/widgets/viewer/info/common.dart';
import 'package:flutter/material.dart';

class XmpStructArrayCard extends StatefulWidget {
  final String title;
  late final List<Map<String, String>> structs;
  final Map<String, InfoValueSpanBuilder> Function(int index)? linkifier;

  XmpStructArrayCard({
    super.key,
    required this.title,
    required Map<int, Map<String, String>> structByIndex,
    this.linkifier,
  }) {
    final length = structByIndex.keys.fold(0, max);
    structs = [for (var i = 0; i < length; i++) structByIndex[i + 1] ?? {}];
  }

  @override
  State<XmpStructArrayCard> createState() => _XmpStructArrayCardState();
}

class _XmpStructArrayCardState extends State<XmpStructArrayCard> {
  late int _index;

  List<Map<String, String>> get structs => widget.structs;

  @override
  void initState() {
    super.initState();
    _index = structs.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    void setIndex(int index) {
      index = index.clamp(0, structs.length - 1);
      if (_index != index) {
        _index = index;
        setState(() {});
      }
    }

    return Card(
      color: Themes.thirdLayerColor(context),
      margin: XmpStructCard.cardMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: HighlightTitle(
                    title: '${widget.title} ${_index + 1}',
                    selectable: true,
                    showHighlight: false,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AIcons.previous),
                  onPressed: _index > 0 ? () => setIndex(_index - 1) : null,
                  tooltip: context.l10n.previousTooltip,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AIcons.next),
                  onPressed: _index < structs.length - 1 ? () => setIndex(_index + 1) : null,
                  tooltip: context.l10n.nextTooltip,
                ),
              ],
            ),
          ),
          MultiCrossFader(
            duration: Durations.xmpStructArrayCardTransition,
            sizeCurve: Curves.easeOutBack,
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              // add padding at this level (instead of the column level)
              // so that the crossfader can animate the content size
              // without clipping the text
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: InfoRowGroup(
                info: structs[_index],
                maxValueLength: Constants.infoGroupMaxValueLength,
                spanBuilders: widget.linkifier?.call(_index + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class XmpStructCard extends StatelessWidget {
  final String title;
  final Map<String, String> struct;
  final Map<String, InfoValueSpanBuilder> Function()? linkifier;

  static const cardMargin = EdgeInsets.symmetric(vertical: 8, horizontal: 0);

  const XmpStructCard({
    super.key,
    required this.title,
    required this.struct,
    this.linkifier,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Themes.thirdLayerColor(context),
      margin: cardMargin,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HighlightTitle(
              title: title,
              selectable: true,
              showHighlight: false,
            ),
            InfoRowGroup(
              info: struct,
              maxValueLength: Constants.infoGroupMaxValueLength,
              spanBuilders: linkifier?.call(),
            ),
          ],
        ),
      ),
    );
  }
}
