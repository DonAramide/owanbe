import 'package:flutter/material.dart';

import '../../eos/widgets/tables/eos_data_table.dart';

/// Legacy table wrapper — use [EosDataTable] in new modules.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) => EosDataTable(columns: columns, rows: rows);
}
