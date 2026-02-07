import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/tab_switcher.dart';

void main() {
  testWidgets('scheduleTabSwitch moves DefaultTabController index',
      (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(key: key),
              const Expanded(
                child: TabBarView(
                  children: [
                    SizedBox(),
                    SizedBox(),
                    SizedBox(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(DefaultTabController.of(key.currentContext!).index, 0);

    scheduleTabSwitch(tabRootKey: key, index: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(DefaultTabController.of(key.currentContext!).index, 2);
  });
}
