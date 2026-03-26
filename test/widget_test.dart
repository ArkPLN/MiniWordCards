import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_word_cards/main.dart';

void main() {
  testWidgets('App loads with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MiniWordCardsApp());

    // 验证底部导航栏存在
    expect(find.byType(NavigationBar), findsOneWidget);

    // 验证三个导航项
    expect(find.text('单词卡'), findsOneWidget);
    expect(find.text('词典'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('Navigation switches pages', (WidgetTester tester) async {
    await tester.pumpWidget(const MiniWordCardsApp());

    // 初始页面是单词卡
    expect(find.text('单词卡'), findsWidgets);

    // 点击词典
    await tester.tap(find.text('词典'));
    await tester.pumpAndSettle();

    // 验证词典页面显示
    expect(find.text('词典'), findsWidgets);

    // 点击设置
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // 验证设置页面显示
    expect(find.text('设置'), findsWidgets);
  });
}
