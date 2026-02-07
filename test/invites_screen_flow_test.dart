import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/screens/invites_screen.dart';
import 'package:not_alone/state/app_state.dart';
import 'package:not_alone/widgets/invite_list.dart';
import 'package:not_alone/widgets/invite_card.dart';

void main() {
  testWidgets('join keeps tab, leave keeps tab, and invite returns to Andras',
      (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invite = {
      'id': 'invite-1',
      'host_user_id': 'host-1',
      'activity': 'dinner',
      'mode': 'one_to_one',
      'max_participants': null,
      'energy': 'medium',
      'talk_level': 'low',
      'duration': 60,
      'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
      'place': 'Gamla Linköping',
      'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
      'invite_members': <Map<String, dynamic>>[],
      'accepted_count': 0,
      'group_id': null,
      'group_name': '',
      'target_gender': 'all',
      'age_min': 18,
      'age_max': 80,
      'host_display_name': 'Test3',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linköping',
          },
          testLoadInvites: () async => [invite],
          testJoinInvite: (_) async => 'member-1',
          testLeaveInvite: (_) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tabBarElement = tester.element(find.byType(TabBar));
    expect(DefaultTabController.of(tabBarElement).index, 0);
    expect(find.widgetWithText(OutlinedButton, 'Gå med'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Gå med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(DefaultTabController.of(tabBarElement).index, 0);
    expect(find.widgetWithText(OutlinedButton, 'Gå med'), findsNothing);
    await tester.tap(find.text('Tackat ja'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Lämna'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lämna'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(DefaultTabController.of(tabBarElement).index, 2);
    await tester.tap(find.text('Andras'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Gå med'), findsOneWidget);
  });

  testWidgets('join does not auto-open meet screen', (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invite = {
      'id': 'invite-1',
      'host_user_id': 'host-1',
      'activity': 'dinner',
      'mode': 'one_to_one',
      'max_participants': null,
      'energy': 'medium',
      'talk_level': 'low',
      'duration': 60,
      'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
      'place': 'Gamla Linkoping',
      'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
      'invite_members': <Map<String, dynamic>>[],
      'accepted_count': 0,
      'group_id': null,
      'group_name': '',
      'target_gender': 'all',
      'age_min': 18,
      'age_max': 80,
      'host_display_name': 'Test3',
    };

    var meetRouteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/meet') {
            meetRouteCount += 1;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Meet')),
            );
          }
          return null;
        },
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linkoping',
          },
          testLoadInvites: () async => [invite],
          testJoinInvite: (_) async => 'member-1',
          testLeaveInvite: (_) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gå med'));
    await tester.pumpAndSettle();

    expect(meetRouteCount, 0);
    expect(find.text('Meet'), findsNothing);
  });

  testWidgets('joining one invite keeps other cards in Andras tab',
      (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invites = <Map<String, dynamic>>[
      {
        'id': 'invite-a',
        'host_user_id': 'host-a',
        'activity': 'dinner',
        'mode': 'one_to_one',
        'max_participants': null,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 60,
        'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
        'place': 'Gamla Linkoping',
        'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[],
        'accepted_count': 0,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'Host A',
      },
      {
        'id': 'invite-b',
        'host_user_id': 'host-b',
        'activity': 'coffee',
        'mode': 'one_to_one',
        'max_participants': null,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 30,
        'meeting_time': DateTime(2026, 2, 7, 12, 0).toIso8601String(),
        'place': 'Stadsparken',
        'created_at': DateTime(2026, 2, 7, 9, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[],
        'accepted_count': 0,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'Host B',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linkoping',
          },
          testLoadInvites: () async => invites,
          testJoinInvite: (inviteId) async {
            if (inviteId == 'invite-a') return 'member-a';
            return null;
          },
          testLeaveInvite: (_) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    var othersList = tester.widget<InviteList>(find.byType(InviteList).first);
    var othersIds = othersList.items.map((it) => it['id']?.toString()).toList();
    expect(othersIds, containsAll(['invite-a', 'invite-b']));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Gå med').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    othersList = tester.widget<InviteList>(find.byType(InviteList).first);
    othersIds = othersList.items.map((it) => it['id']?.toString()).toList();
    expect(othersIds, equals(['invite-b']));
  });

  testWidgets('host invite shows delete action on main button', (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invite = {
      'id': 'invite-host',
      'host_user_id': 'me',
      'activity': 'dinner',
      'mode': 'one_to_one',
      'max_participants': null,
      'energy': 'medium',
      'talk_level': 'low',
      'duration': 60,
      'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
      'place': 'Gamla Linkoping',
      'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
      'invite_members': <Map<String, dynamic>>[],
      'accepted_count': 0,
      'group_id': null,
      'group_name': '',
      'target_gender': 'all',
      'age_min': 18,
      'age_max': 80,
      'host_display_name': 'Me',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linkoping',
          },
          testLoadInvites: () async => [invite],
          testJoinInvite: (_) async => null,
          testLeaveInvite: (_) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Mina'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Radera'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Gå med'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Radera'));
    await tester.pumpAndSettle();

    expect(find.text('Ta bort inbjudan?'), findsOneWidget);
  });

  testWidgets('leaving one joined invite keeps other joined invites',
      (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invites = <Map<String, dynamic>>[
      {
        'id': 'invite-a',
        'host_user_id': 'host-a',
        'activity': 'dinner',
        'mode': 'one_to_one',
        'max_participants': null,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 60,
        'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
        'place': 'Gamla Linkoping',
        'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[],
        'accepted_count': 0,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'TestA',
      },
      {
        'id': 'invite-b',
        'host_user_id': 'host-b',
        'activity': 'coffee',
        'mode': 'group',
        'max_participants': 4,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 30,
        'meeting_time': DateTime(2026, 2, 7, 12, 0).toIso8601String(),
        'place': 'Stadsparken',
        'created_at': DateTime(2026, 2, 7, 9, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[
          {'id': 'member-b', 'user_id': 'me', 'status': 'accepted'}
        ],
        'accepted_count': 1,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'TestB',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linkoping',
          },
          testLoadInvites: () async => invites,
          testJoinInvite: (inviteId) async {
            if (inviteId == 'invite-a') {
              invites[0]['invite_members'] = <Map<String, dynamic>>[
                {'id': 'member-a', 'user_id': 'me', 'status': 'accepted'}
              ];
              return 'member-a';
            }
            return null;
          },
          testLeaveInvite: (inviteMemberId) async {
            for (final invite in invites) {
              final members =
                  (invite['invite_members'] as List).cast<Map<String, dynamic>>();
              for (final member in members) {
                if (member['id']?.toString() == inviteMemberId) {
                  member['status'] = 'cannot_attend';
                }
              }
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Gå med').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Tackat ja'));
    await tester.pumpAndSettle();
    var joinedList = tester.widget<InviteList>(find.byType(InviteList).first);
    var joinedIds =
        joinedList.items.map((it) => it['id']?.toString()).toList();
    expect(joinedIds, containsAll(['invite-a', 'invite-b']));

    final joinedCards = tester.widgetList<InviteCard>(find.byType(InviteCard));
    final cardToLeave = joinedCards.firstWhere(
      (card) => card.hostDisplayName == 'TestA',
    );
    cardToLeave.onJoin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Tackat ja'));
    await tester.pumpAndSettle();

    joinedList = tester.widget<InviteList>(find.byType(InviteList).first);
    joinedIds = joinedList.items.map((it) => it['id']?.toString()).toList();
    expect(joinedIds, equals(['invite-b']));
  });

  testWidgets('leaving invite keeps other joined invites on reload failure',
      (tester) async {
    final appState = AppState();
    appState.setLocale(const Locale('sv'));

    final invites = <Map<String, dynamic>>[
      {
        'id': 'invite-a',
        'host_user_id': 'host-a',
        'activity': 'dinner',
        'mode': 'one_to_one',
        'max_participants': null,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 60,
        'meeting_time': DateTime(2026, 2, 7, 10, 0).toIso8601String(),
        'place': 'Gamla Linkoping',
        'created_at': DateTime(2026, 2, 7, 8, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[],
        'accepted_count': 0,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'TestA',
      },
      {
        'id': 'invite-b',
        'host_user_id': 'host-b',
        'activity': 'coffee',
        'mode': 'group',
        'max_participants': 4,
        'energy': 'medium',
        'talk_level': 'low',
        'duration': 30,
        'meeting_time': DateTime(2026, 2, 7, 12, 0).toIso8601String(),
        'place': 'Stadsparken',
        'created_at': DateTime(2026, 2, 7, 9, 0).toIso8601String(),
        'invite_members': <Map<String, dynamic>>[
          {'id': 'member-b', 'user_id': 'me', 'status': 'accepted'}
        ],
        'accepted_count': 1,
        'group_id': null,
        'group_name': '',
        'target_gender': 'all',
        'age_min': 18,
        'age_max': 80,
        'host_display_name': 'TestB',
      },
    ];

    var loadCount = 0;
    Future<List<Map<String, dynamic>>> loadInvites() async {
      loadCount += 1;
      if (loadCount == 1) return invites;
      throw Exception('Network is unreachable');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: InvitesScreen(
          appState: appState,
          testCurrentUserId: 'me',
          testCurrentUserMetadata: const {
            'username': 'me',
            'age': 30,
            'gender': 'male',
            'city': 'Linkoping',
          },
          testLoadInvites: loadInvites,
          testJoinInvite: (inviteId) async {
            if (inviteId == 'invite-a') {
              invites[0]['invite_members'] = <Map<String, dynamic>>[
                {'id': 'member-a', 'user_id': 'me', 'status': 'accepted'}
              ];
              return 'member-a';
            }
            return null;
          },
          testLeaveInvite: (inviteMemberId) async {
            for (final invite in invites) {
              final members =
                  (invite['invite_members'] as List).cast<Map<String, dynamic>>();
              for (final member in members) {
                if (member['id']?.toString() == inviteMemberId) {
                  member['status'] = 'cannot_attend';
                }
              }
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Gå med').first);
    await tester.pump();
    await tester.pumpAndSettle();

    final afterJoinTabBar = tester.element(find.byType(TabBar));
    if (DefaultTabController.of(afterJoinTabBar).index != 2) {
      await tester.tap(find.text('Tackat ja'));
      await tester.pumpAndSettle();
    }

    final card = tester.widget<InviteCard>(find.byType(InviteCard).first);
    card.onJoin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tabBarElement = tester.element(find.byType(TabBar));
    await tester.tap(find.text('Tackat ja'));
    await tester.pumpAndSettle();

    expect(DefaultTabController.of(tabBarElement).index, 2);

    final joinedList =
        tester.widget<InviteList>(find.byType(InviteList).first);
    final joinedIds =
        joinedList.items.map((it) => it['id']?.toString()).toList();
    expect(joinedIds, equals(['invite-b']));
  });
}
