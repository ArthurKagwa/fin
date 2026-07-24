import 'package:flutter/material.dart';

class IncomeListScreen extends StatelessWidget {
  const IncomeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Money In',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: const Center(child: Text('Income — coming soon')),
    );
  }
}
