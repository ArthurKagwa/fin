import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/planning/presentation/plan_editor_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Edits the plan for whichever month the report is showing.
///
/// Scoped to [selectedPlanMonthProvider] rather than a path parameter: the
/// month is already app state, and saving a plan against a month the user
/// isn't looking at is a mistake waiting to happen. The current month is
/// budgeted on the Plan tab instead; this is the way back into an earlier one
/// from its report.
class PlanEditorScreen extends ConsumerWidget {
  const PlanEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPlanMonthProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Plan for ${formatMonth(month)}')),
      body: PlanEditorForm(
        month: month,
        onSaved: () => context.pop(),
      ),
    );
  }
}
