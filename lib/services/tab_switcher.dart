import 'package:flutter/material.dart';

void scheduleTabSwitch({
  required GlobalKey tabRootKey,
  required int index,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final tabContext = tabRootKey.currentContext;
    if (tabContext == null) return;
    final controller = DefaultTabController.of(tabContext);
    controller.animateTo(index);
  });
}
