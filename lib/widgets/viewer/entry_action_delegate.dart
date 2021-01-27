import 'dart:convert';

import 'package:aves/model/actions/entry_actions.dart';
import 'package:aves/model/actions/move_type.dart';
import 'package:aves/model/entry.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/android_app_service.dart';
import 'package:aves/services/image_file_service.dart';
import 'package:aves/services/image_op_events.dart';
import 'package:aves/services/metadata_service.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/action_mixins/permission_aware.dart';
import 'package:aves/widgets/common/action_mixins/size_aware.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves/widgets/dialogs/rename_entry_dialog.dart';
import 'package:aves/widgets/filter_grids/album_pick.dart';
import 'package:aves/widgets/viewer/debug_page.dart';
import 'package:aves/widgets/viewer/info/notifications.dart';
import 'package:aves/widgets/viewer/printer.dart';
import 'package:aves/widgets/viewer/source_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

class EntryActionDelegate with FeedbackMixin, PermissionAwareMixin, SizeAwareMixin {
  final CollectionLens collection;
  final VoidCallback showInfo;

  EntryActionDelegate({
    @required this.collection,
    @required this.showInfo,
  });

  bool get hasCollection => collection != null;

  void onActionSelected(BuildContext context, AvesEntry entry, EntryAction action) {
    switch (action) {
      case EntryAction.toggleFavourite:
        entry.toggleFavourite();
        break;
      case EntryAction.delete:
        _showDeleteDialog(context, entry);
        break;
      case EntryAction.export:
        _showExportDialog(context, entry);
        break;
      case EntryAction.info:
        showInfo();
        break;
      case EntryAction.rename:
        _showRenameDialog(context, entry);
        break;
      case EntryAction.print:
        EntryPrinter(entry).print();
        break;
      case EntryAction.rotateCCW:
        _rotate(context, entry, clockwise: false);
        break;
      case EntryAction.rotateCW:
        _rotate(context, entry, clockwise: true);
        break;
      case EntryAction.flip:
        _flip(context, entry);
        break;
      case EntryAction.edit:
        AndroidAppService.edit(entry.uri, entry.mimeType).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
        break;
      case EntryAction.open:
        AndroidAppService.open(entry.uri, entry.mimeTypeAnySubtype).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
        break;
      case EntryAction.openMap:
        AndroidAppService.openMap(entry.geoUri).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
        break;
      case EntryAction.setAs:
        AndroidAppService.setAs(entry.uri, entry.mimeType).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
        break;
      case EntryAction.share:
        AndroidAppService.shareEntries({entry}).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
        break;
      case EntryAction.viewSource:
        _goToSourceViewer(context, entry);
        break;
      case EntryAction.debug:
        _goToDebug(context, entry);
        break;
    }
  }

  Future<void> _flip(BuildContext context, AvesEntry entry) async {
    if (!await checkStoragePermission(context, {entry})) return;

    final success = await entry.flip();
    if (!success) showFeedback(context, 'Failed');
  }

  Future<void> _rotate(BuildContext context, AvesEntry entry, {@required bool clockwise}) async {
    if (!await checkStoragePermission(context, {entry})) return;

    final success = await entry.rotate(clockwise: clockwise);
    if (!success) showFeedback(context, 'Failed');
  }

  Future<void> _showDeleteDialog(BuildContext context, AvesEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AvesDialog(
          context: context,
          content: Text('Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.toUpperCase()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete'.toUpperCase()),
            ),
          ],
        );
      },
    );
    if (confirmed == null || !confirmed) return;

    if (!await checkStoragePermission(context, {entry})) return;

    if (!await entry.delete()) {
      showFeedback(context, 'Failed');
    } else {
      if (hasCollection) {
        collection.source.removeEntries([entry]);
      }
      EntryDeletedNotification(entry).dispatch(context);
    }
  }

  Future<void> _showExportDialog(BuildContext context, AvesEntry entry) async {
    final source = context.read<CollectionSource>();
    if (!source.initialized) {
      await source.init();
      unawaited(source.refresh());
    }
    final destinationAlbum = await Navigator.push(
      context,
      MaterialPageRoute<String>(
        settings: RouteSettings(name: AlbumPickPage.routeName),
        builder: (context) => AlbumPickPage(source: source, moveType: MoveType.export),
      ),
    );

    if (destinationAlbum == null || destinationAlbum.isEmpty) return;
    if (!await checkStoragePermissionForAlbums(context, {destinationAlbum})) return;

    if (!await checkStoragePermission(context, {entry})) return;

    if (!await checkFreeSpaceForMove(context, {entry}, destinationAlbum, MoveType.export)) return;

    final selection = <AvesEntry>{};
    if (entry.isMultipage) {
      final multiPageInfo = await MetadataService.getMultiPageInfo(entry);
      if (multiPageInfo.pageCount > 1) {
        for (final page in multiPageInfo.pages) {
          final pageEntry = entry.getPageEntry(page, eraseDefaultPageId: false);
          selection.add(pageEntry);
        }
      }
    } else {
      selection.add(entry);
    }

    showOpReport<ExportOpEvent>(
      context: context,
      selection: selection,
      opStream: ImageFileService.export(selection, destinationAlbum: destinationAlbum),
      onDone: (processed) {
        final movedOps = processed.where((e) => e.success);
        final movedCount = movedOps.length;
        final selectionCount = selection.length;
        if (movedCount < selectionCount) {
          final count = selectionCount - movedCount;
          showFeedback(context, 'Failed to export ${Intl.plural(count, one: '$count page', other: '$count pages')}');
        } else {
          showFeedback(context, 'Done!');
        }
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context, AvesEntry entry) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameEntryDialog(entry),
    );
    if (newName == null || newName.isEmpty) return;

    if (!await checkStoragePermission(context, {entry})) return;

    showFeedback(context, await entry.rename(newName) ? 'Done!' : 'Failed');
  }

  void _goToSourceViewer(BuildContext context, AvesEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: SourceViewerPage.routeName),
        builder: (context) => SourceViewerPage(
          loader: () => ImageFileService.getSvg(entry.uri, entry.mimeType).then(utf8.decode),
        ),
      ),
    );
  }

  void _goToDebug(BuildContext context, AvesEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: ViewerDebugPage.routeName),
        builder: (context) => ViewerDebugPage(entry: entry),
      ),
    );
  }
}