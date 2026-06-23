import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_radius.dart';
import '../cards/eos_surface_card.dart';

class EosDataTable extends StatelessWidget {
  const EosDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records',
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EosSurfaceCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Text(emptyMessage, style: context.eosText.bodyMedium),
          ),
        ),
      );
    }

    return EosSurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: EosRadius.card,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(context.eosColors.surfaceContainerHighest),
            columns: columns,
            rows: rows,
            columnSpacing: context.eos.spacing.lg,
            horizontalMargin: context.eos.spacing.md,
          ),
        ),
      ),
    );
  }
}
