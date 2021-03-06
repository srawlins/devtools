// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose_mixin.dart';
import 'common_widgets.dart';
import 'connected_app.dart';
import 'globals.dart';
import 'info/info_controller.dart';
import 'table.dart';
import 'table_data.dart';
import 'theme.dart';
import 'utils.dart';
import 'version.dart';

class DeviceDialog extends StatelessWidget {
  const DeviceDialog({
    @required this.connectedApp,
    @required this.flutterVersion,
  });

  final ConnectedApp connectedApp;
  final FlutterVersion flutterVersion;

  @override
  Widget build(BuildContext context) {
    const boldText = TextStyle(fontWeight: FontWeight.bold);
    final theme = Theme.of(context);

    final vm = serviceManager.vm;

    var version = vm.version;
    // Convert '2.9.0-13.0.dev (dev) (Fri May ... +0200) on "macos_x64"' to
    // '2.9.0-13.0.dev'.
    if (version.contains(' ')) {
      version = version.substring(0, version.indexOf(' '));
    }

    var bits = '';
    if (vm.architectureBits != -1) {
      bits = '-${vm.architectureBits}';
    }

    final items = {
      'Dart Version': version,
      'CPU / OS': '${vm.targetCPU}$bits / ${vm.operatingSystem}',
    };

    if (flutterVersion != null) {
      items['Flutter Version'] =
          '${flutterVersion.version} / ${flutterVersion.channel}';
      items['Framework / Engine'] = '${flutterVersion.frameworkRevision} / '
          '${flutterVersion.engineRevision}';
    }

    return AlertDialog(
      actions: [
        if (connectedApp.isRunningOnDartVM) _ViewVMFlagsButton(),
        DialogCloseButton(),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...headerInColumn(theme.textTheme, 'Device Info'),
          for (var name in items.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: denseRowSpacing),
              child: Row(
                children: [
                  Text('$name: ', style: boldText),
                  Text(items[name], style: theme.subtleTextStyle),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewVMFlagsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop('dialog');

        unawaited(showDialog(
          context: context,
          builder: (context) => VMFlagsDialog(),
        ));
      },
      child: Text('View VM Flags...'.toUpperCase()),
    );
  }
}

class VMFlagsDialog extends StatefulWidget {
  @override
  _VMFlagsDialogState createState() => _VMFlagsDialogState();
}

class _VMFlagsDialogState extends State<VMFlagsDialog> with AutoDisposeMixin {
  InfoController infoController;
  TextEditingController filterController;

  List<_DialogFlag> flags = [];
  List<_DialogFlag> filteredFlags = [];

  @override
  void initState() {
    super.initState();

    infoController = InfoController();

    filterController = TextEditingController();
    filterController.addListener(() {
      setState(() {
        _refilter();
      });
    });

    _updateFromController();
    addAutoDisposeListener(infoController.flagListNotifier, () {
      setState(() {
        _updateFromController();
      });
    });
  }

  void _updateFromController() {
    flags = infoController.flagListNotifier.value.flags
        .map((flag) => _DialogFlag(flag))
        .toList();
    _refilter();
  }

  void _refilter() {
    final filter = filterController.text.trim().toLowerCase();

    if (filter.isEmpty) {
      filteredFlags = flags;
    } else {
      filteredFlags =
          flags.where((flag) => flag.filterText.contains(filter)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      actions: [
        DialogCloseButton(),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('VM Flags', style: textTheme.headline6),
              const Expanded(child: SizedBox(width: denseSpacing)),
              Container(
                width: defaultSearchTextWidth,
                height: defaultSearchTextHeight,
                child: TextField(
                  controller: filterController,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Filter',
                  ),
                ),
              ),
            ],
          ),
          const PaddedDivider(
              padding: EdgeInsets.only(bottom: denseRowSpacing)),
          SizedBox(
            width: 875,
            height: 375,
            child: _FlagTable(filteredFlags),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    infoController.dispose();

    super.dispose();
  }
}

class _FlagTable extends StatelessWidget {
  _FlagTable(this.flags);

  final List<_DialogFlag> flags;

  final ColumnData<_DialogFlag> name = _NameColumn();
  final ColumnData<_DialogFlag> description = _DescriptionColumn();
  final ColumnData<_DialogFlag> value = _ValueColumn();

  List<ColumnData<_DialogFlag>> get columns => [name, description, value];

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: FlatTable<_DialogFlag>(
        columns: columns,
        data: flags,
        keyFactory: (_DialogFlag flag) => ValueKey<String>(flag.name),
        sortColumn: name,
        sortDirection: SortDirection.ascending,
        onItemSelected: (_) => null,
      ),
    );
  }
}

class _NameColumn extends ColumnData<_DialogFlag> {
  _NameColumn() : super('Name', fixedWidthPx: 180);

  @override
  String getValue(_DialogFlag dataObject) => dataObject.name;
}

class _DescriptionColumn extends ColumnData<_DialogFlag> {
  _DescriptionColumn() : super.wide('Description');

  @override
  String getValue(_DialogFlag dataObject) => dataObject.description;

  @override
  String getTooltip(_DialogFlag dataObject) => getValue(dataObject);
}

class _ValueColumn extends ColumnData<_DialogFlag> {
  _ValueColumn()
      : super('Value', fixedWidthPx: 160, alignment: ColumnAlignment.right);

  @override
  String getValue(_DialogFlag dataObject) => dataObject.value;
}

class _DialogFlag {
  _DialogFlag(this.flag)
      : filterText = '${flag.name.toLowerCase()}\n'
            '${flag.comment.toLowerCase()}\n'
            '${flag.valueAsString.toLowerCase()}';

  final Flag flag;
  final String filterText;

  String get name => flag.name;

  String get description => flag.comment;

  String get value => flag.valueAsString;
}
