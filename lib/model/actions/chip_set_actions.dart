import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/widgets.dart';

enum ChipSetAction {
  // general
  sort,
  group,
  select,
  selectAll,
  selectNone,
  stats,
  createAlbum,
  // single/multiple filters
  delete,
  hide,
  pin,
  unpin,
  // single filter
  rename,
  setCover,
}

extension ExtraChipSetAction on ChipSetAction {
  String getText(BuildContext context) {
    switch (this) {
      // general
      case ChipSetAction.sort:
        return context.l10n.menuActionSort;
      case ChipSetAction.group:
        return context.l10n.menuActionGroup;
      case ChipSetAction.select:
        return context.l10n.collectionActionSelect;
      case ChipSetAction.selectAll:
        return context.l10n.collectionActionSelectAll;
      case ChipSetAction.selectNone:
        return context.l10n.collectionActionSelectNone;
      case ChipSetAction.stats:
        return context.l10n.menuActionStats;
      case ChipSetAction.createAlbum:
        return context.l10n.chipActionCreateAlbum;
      // single/multiple filters
      case ChipSetAction.delete:
        return context.l10n.chipActionDelete;
      case ChipSetAction.hide:
        return context.l10n.chipActionHide;
      case ChipSetAction.pin:
        return context.l10n.chipActionPin;
      case ChipSetAction.unpin:
        return context.l10n.chipActionUnpin;
      // single filter
      case ChipSetAction.rename:
        return context.l10n.chipActionRename;
      case ChipSetAction.setCover:
        return context.l10n.chipActionSetCover;
    }
  }

  IconData? getIcon() {
    switch (this) {
      // general
      case ChipSetAction.sort:
        return AIcons.sort;
      case ChipSetAction.group:
        return AIcons.group;
      case ChipSetAction.select:
        return AIcons.select;
      case ChipSetAction.selectAll:
      case ChipSetAction.selectNone:
        return null;
      case ChipSetAction.stats:
        return AIcons.stats;
      case ChipSetAction.createAlbum:
        return AIcons.createAlbum;
      // single/multiple filters
      case ChipSetAction.delete:
        return AIcons.delete;
      case ChipSetAction.hide:
        return AIcons.hide;
      case ChipSetAction.pin:
        return AIcons.pin;
      case ChipSetAction.unpin:
        return AIcons.unpin;
      // single filter
      case ChipSetAction.rename:
        return AIcons.rename;
      case ChipSetAction.setCover:
        return AIcons.setCover;
    }
  }
}
