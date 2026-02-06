import 'package:flutter/material.dart';

typedef InviteItemBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> item,
);

class InviteList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyLabel;
  final InviteItemBuilder itemBuilder;

  const InviteList({
    super.key,
    required this.items,
    required this.emptyLabel,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => itemBuilder(context, items[i]),
    );
  }
}
