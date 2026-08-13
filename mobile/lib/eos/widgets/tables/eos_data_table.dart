import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../layout/eos_responsive.dart';
import '../../tokens/eos_radius.dart';
import '../cards/eos_surface_card.dart';
import '../../../core/utils/export_helper.dart';

class EosDataTable extends StatefulWidget {
  const EosDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records',
    this.onSearch,
    this.onExport,
    this.onRowSelectedChanged,
    this.bulkActions = const [],
    this.onBulkAction,
    this.savedFilters = const [],
    this.onFilterSelected,
    this.columnSelectorEnabled = true,
    this.onRowTap,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onExport;
  final ValueChanged<List<int>>? onRowSelectedChanged;
  final List<String> bulkActions;
  final void Function(String action, List<int> selectedIndices)? onBulkAction;
  final List<String> savedFilters;
  final ValueChanged<String>? onFilterSelected;
  final bool columnSelectorEnabled;
  final ValueChanged<int>? onRowTap;

  @override
  State<EosDataTable> createState() => _EosDataTableState();
}

class _EosDataTableState extends State<EosDataTable> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIndices = {};
  late List<bool> _visibleColumns;
  int _currentPage = 1;
  int _rowsPerPage = 5;
  String _activeFilter = '';

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.filled(widget.columns.length, true);
    if (widget.savedFilters.isNotEmpty) {
      _activeFilter = widget.savedFilters.first;
    }
  }

  @override
  void didUpdateWidget(covariant EosDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.columns.length != _visibleColumns.length) {
      _visibleColumns = List.filled(widget.columns.length, true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIndices.clear();
        for (int i = 0; i < widget.rows.length; i++) {
          _selectedIndices.add(i);
        }
      } else {
        _selectedIndices.clear();
      }
      widget.onRowSelectedChanged?.call(_selectedIndices.toList());
    });
  }

  void _toggleSelectRow(int index, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
      widget.onRowSelectedChanged?.call(_selectedIndices.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = widget.rows.where((row) {
      if (_searchController.text.isEmpty) return true;
      final query = _searchController.text.toLowerCase();
      // Simple search within row cells
      for (final cell in row.cells) {
        final cellText = _cellTextValue(cell).toLowerCase();
        if (cellText.contains(query)) return true;
      }
      return false;
    }).toList();

    // Pagination slice
    final totalPages = (filteredRows.length / _rowsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage > filteredRows.length
        ? filteredRows.length
        : startIndex + _rowsPerPage;

    final paginatedRows = filteredRows.isEmpty
        ? <DataRow>[]
        : filteredRows.sublist(startIndex, endIndex);

    final showBulkBar = _selectedIndices.isNotEmpty && widget.bulkActions.isNotEmpty;
    final useCards = EosResponsive.useCardDataPresentation(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Grid Toolbar
        _buildToolbar(context, filteredRows.length),

        if (showBulkBar) _buildBulkActionsBar(context),

        const SizedBox(height: 8),

        // 2. Main Data Grid — table on medium/expanded, cards on compact
        if (filteredRows.isEmpty)
          EosSurfaceCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                child: Text(widget.emptyMessage, style: context.eosText.bodyMedium),
              ),
            ),
          )
        else if (useCards)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int rIndex = 0; rIndex < paginatedRows.length; rIndex++) ...[
                if (rIndex > 0) SizedBox(height: context.eos.spacing.sm),
                _buildMobileCard(context, paginatedRows[rIndex], startIndex + rIndex),
              ],
              _buildPaginationControls(context, filteredRows.length, totalPages),
            ],
          )
        else
          EosSurfaceCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: EosRadius.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        context.eosColors.surfaceContainerHighest,
                      ),
                      columnSpacing: context.eos.spacing.lg,
                      horizontalMargin: context.eos.spacing.md,
                      columns: [
                        // Checkbox column header
                        if (widget.onRowSelectedChanged != null)
                          DataColumn(
                            label: Checkbox(
                              value: _selectedIndices.length == widget.rows.length,
                              tristate: _selectedIndices.isNotEmpty &&
                                  _selectedIndices.length < widget.rows.length,
                              onChanged: _toggleSelectAll,
                            ),
                          ),
                        // Dynamic visible columns
                        for (int i = 0; i < widget.columns.length; i++)
                          if (_visibleColumns[i]) widget.columns[i],
                      ],
                      rows: [
                        for (int rIndex = 0; rIndex < paginatedRows.length; rIndex++)
                          DataRow(
                            selected: _selectedIndices.contains(startIndex + rIndex),
                            onSelectChanged: widget.onRowSelectedChanged != null
                                ? (val) => _toggleSelectRow(startIndex + rIndex, val)
                                : (widget.onRowTap != null
                                    ? (_) => widget.onRowTap?.call(startIndex + rIndex)
                                    : null),
                            cells: [
                              if (widget.onRowSelectedChanged != null)
                                DataCell(
                                  Checkbox(
                                    value: _selectedIndices.contains(startIndex + rIndex),
                                    onChanged: (val) =>
                                        _toggleSelectRow(startIndex + rIndex, val),
                                  ),
                                ),
                              for (int cIndex = 0; cIndex < widget.columns.length; cIndex++)
                                if (_visibleColumns[cIndex])
                                  DataCell(
                                    InkWell(
                                      onTap: widget.onRowTap != null
                                          ? () => widget.onRowTap?.call(startIndex + rIndex)
                                          : null,
                                      child: paginatedRows[rIndex].cells[cIndex].child,
                                    ),
                                  ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // 3. Pagination Controls
                  _buildPaginationControls(context, filteredRows.length, totalPages),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileCard(BuildContext context, DataRow row, int absoluteIndex) {
    final labels = <String>[];
    for (var i = 0; i < widget.columns.length; i++) {
      if (!_visibleColumns[i]) continue;
      final labelWidget = widget.columns[i].label;
      labels.add(labelWidget is Text ? (labelWidget.data ?? 'Col $i') : 'Col $i');
    }

    final visibleCells = <Widget>[];
    for (var i = 0; i < widget.columns.length; i++) {
      if (!_visibleColumns[i]) continue;
      visibleCells.add(row.cells[i].child);
    }

    return EosSurfaceCard(
      onTap: widget.onRowTap != null ? () => widget.onRowTap!(absoluteIndex) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onRowSelectedChanged != null)
            Align(
              alignment: Alignment.centerRight,
              child: Checkbox(
                value: _selectedIndices.contains(absoluteIndex),
                onChanged: (val) => _toggleSelectRow(absoluteIndex, val),
              ),
            ),
          for (var i = 0; i < visibleCells.length; i++) ...[
            if (i > 0) SizedBox(height: context.eos.spacing.sm),
            Text(
              labels[i],
              style: context.eosText.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.eos.spacing.xxs),
            DefaultTextStyle(
              style: context.eosText.bodyMedium ?? const TextStyle(),
              child: visibleCells[i],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, int resultCount) {
    final compact = EosResponsive.isCompact(context);
    final tools = <Widget>[
      if (widget.savedFilters.isNotEmpty)
        DropdownButton<String>(
          value: _activeFilter,
          icon: const Icon(Icons.filter_list, size: 16),
          style: context.eosText.bodySmall,
          underline: const SizedBox(),
          items: widget.savedFilters.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text('Filter: $value'),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _activeFilter = val;
              });
              widget.onFilterSelected?.call(val);
            }
          },
        ),
      if (widget.columnSelectorEnabled && !compact)
        PopupMenuButton<int>(
          icon: const Icon(Icons.view_column, size: 18),
          tooltip: 'Choose Columns',
          itemBuilder: (context) {
            return List.generate(widget.columns.length, (idx) {
              final labelWidget = widget.columns[idx].label;
              final labelText = labelWidget is Text ? labelWidget.data ?? 'Col $idx' : 'Col $idx';
              return CheckedPopupMenuItem<int>(
                value: idx,
                checked: _visibleColumns[idx],
                child: Text(labelText),
              );
            });
          },
          onSelected: (idx) {
            setState(() {
              _visibleColumns[idx] = !_visibleColumns[idx];
            });
          },
        ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.download, size: 18),
        tooltip: 'Export Data',
        onSelected: (format) {
          if (widget.onExport != null) {
            widget.onExport!.call(format);
          } else {
            _localExport(format);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported grid as $format successfully.')),
          );
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'CSV', child: Text('Export to CSV')),
          const PopupMenuItem(value: 'Excel', child: Text('Export to Excel')),
          const PopupMenuItem(value: 'PDF', child: Text('Export as PDF Document')),
        ],
      ),
    ];

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search table records...',
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) {
        setState(() {
          _currentPage = 1;
        });
        widget.onSearch?.call(val);
      },
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: tools),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.maxWidth.isFinite && constraints.maxWidth > 0;
          final searchField = SizedBox(
            width: bounded ? null : 280,
            child: search,
          );
          return Row(
            children: [
              if (bounded)
                Expanded(child: search)
              else
                searchField,
              const SizedBox(width: 12),
              for (final t in tools) ...[
                t,
                const SizedBox(width: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkActionsBar(BuildContext context) {
    final compact = EosResponsive.isCompact(context);
    return Container(
      color: context.eosColors.secondaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_selectedIndices.length} items selected',
                  style: context.eosText.labelMedium?.copyWith(color: context.eosColors.onSecondaryContainer),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in widget.bulkActions)
                      OutlinedButton(
                        onPressed: () {
                          widget.onBulkAction?.call(action, _selectedIndices.toList());
                          setState(() {
                            _selectedIndices.clear();
                          });
                        },
                        child: Text(action, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  '${_selectedIndices.length} items selected',
                  style: context.eosText.labelMedium?.copyWith(color: context.eosColors.onSecondaryContainer),
                ),
                const Spacer(),
                for (final action in widget.bulkActions)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onBulkAction?.call(action, _selectedIndices.toList());
                        setState(() {
                          _selectedIndices.clear();
                        });
                      },
                      child: Text(action, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPaginationControls(BuildContext context, int totalRows, int totalPages) {
    final compact = EosResponsive.isCompact(context);
    final rangeLabel =
        'Showing ${totalRows == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1} - ${(_currentPage * _rowsPerPage) > totalRows ? totalRows : (_currentPage * _rowsPerPage)} of $totalRows';
    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Text('Rows/page: ', style: context.eosText.bodySmall),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: [5, 10, 20].map((int val) {
              return DropdownMenuItem<int>(
                value: val,
                child: Text('$val', style: context.eosText.bodySmall),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _rowsPerPage = val;
                  _currentPage = 1;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          '$_currentPage / ${totalPages == 0 ? 1 : totalPages}',
          style: context.eosText.bodySmall,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.eosColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: context.eosColors.outlineVariant)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(rangeLabel, style: context.eosText.bodySmall),
                Align(alignment: Alignment.centerRight, child: pager),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(rangeLabel, style: context.eosText.bodySmall)),
                pager,
              ],
            ),
    );
  }

  String _cellTextValue(DataCell cell) {
    final child = cell.child;
    if (child is Text) return child.data ?? '';
    if (child is Container) {
      // Walk child tree if it is a container
      final cChild = child.child;
      if (cChild is Text) return cChild.data ?? '';
    }
    return '';
  }

  void _localExport(String format) async {
    final csvContent = _generateCsvContent();
    final filename = 'export_${DateTime.now().millisecondsSinceEpoch}.${format.toLowerCase() == 'csv' ? 'csv' : 'txt'}';
    await ExportHelper.downloadFile(filename, csvContent, mimeType: format.toLowerCase() == 'csv' ? 'text/csv' : 'text/plain');
  }

  String _generateCsvContent() {
    final buffer = StringBuffer();
    final headerList = <String>[];
    for (int i = 0; i < widget.columns.length; i++) {
      if (_visibleColumns[i]) {
        final labelWidget = widget.columns[i].label;
        final labelText = labelWidget is Text ? labelWidget.data ?? '' : 'Col $i';
        headerList.add('"$labelText"');
      }
    }
    buffer.writeln(headerList.join(','));

    for (final row in widget.rows) {
      final rowData = <String>[];
      for (int i = 0; i < widget.columns.length; i++) {
        if (_visibleColumns[i]) {
          final cellText = _cellTextValue(row.cells[i]);
          rowData.add('"$cellText"');
        }
      }
      buffer.writeln(rowData.join(','));
    }
    return buffer.toString();
  }
}
