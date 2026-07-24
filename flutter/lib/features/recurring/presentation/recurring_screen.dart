import 'package:flutter/material.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recurring',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: const Center(child: Text('Recurring payments — coming soon')),
    );
  }
}
