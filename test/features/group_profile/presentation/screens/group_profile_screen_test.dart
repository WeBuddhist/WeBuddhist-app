import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_pecha/features/auth/presentation/state/user_state.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_post.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_unread_dot.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_rooms_list.dart';
import 'package:flutter_pecha/features/group_profile/data/datasource/group_profile_remote_datasource.dart';
import 'package:flutter_pecha/features/group_profile/data/repositories/group_profile_repository_impl.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_post_permission.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_pecha/features/group_profile/domain/repositories/group_post_repository.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_post_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_reports_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/screens/group_profile_screen.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

class _SignedInAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedInAuth() : super(const AuthState(isLoggedIn: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoUser extends StateNotifier<UserState> implements UserNotifier {
  _NoUser() : super(const UserState.initial());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedContentLanguage extends StateNotifier<String>
    implements ContentLanguageNotifier {
  _FixedContentLanguage() : super('en');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakePostRepository extends Fake
    implements GroupPostRepositoryInterface {}

/// Reports queue whose total the test raises after the page has settled.
class _StubReports extends StateNotifier<GroupReportsState>
    implements GroupReportsNotifier {
  _StubReports() : super(const GroupReportsState(hasLoaded: true));

  void setTotal(int total) =>
      state = GroupReportsState(total: total, hasLoaded: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// One space with nothing posted, so only the Members tab shows.
class _FakeRemote extends GroupProfileRemoteDatasource {
  _FakeRemote() : super(dio: Dio());

  String groupType = 'COMMUNITY';
  bool isMember = true;

  @override
  Future<Map<String, dynamic>> fetchGroupProfileJson(
    String groupId, {
    required String language,
  }) async => {
    'id': groupId,
    'slug': groupId,
    'group_type': groupType,
    'is_public': true,
    'is_following': isMember,
    'joiner_count': 2,
    'metadata': {'title': 'Semkyed', 'description': 'A quiet space'},
  };

  @override
  Future<Map<String, dynamic>> fetchGroupEventsJson(
    String groupId, {
    required String language,
  }) async => {'events': [], 'total': 0, 'skip': 0, 'limit': 20};

  @override
  Future<Map<String, dynamic>> fetchPracticesJson({
    String? groupId,
    required bool includeUnfollowed,
    required String language,
    required int skip,
    required int limit,
  }) async => {'practices': [], 'total': 0, 'skip': 0, 'limit': 20};

  @override
  Future<Map<String, dynamic>> fetchGroupMembersJson(
    String groupId, {
    required int skip,
    required int limit,
  }) async => {
    'list': [
      for (var i = 0; i < 30; i++)
        {'user_id': 'u$i', 'username': 'u$i', 'fullname': 'Member $i'},
    ],
    'skip': skip,
    'limit': limit,
    'total_members': 30,
  };

  @override
  Future<bool> checkFollowStatus(String groupId, GroupType groupType) async =>
      isMember;
}

void main() {
  late _FakeRemote remote;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool startCollapsed = false,
    Widget? home,
    Map<String, SpaceUnread> unread = const {},
    String? role,
    _StubReports? reports,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        userProvider.overrideWith((ref) => _NoUser()),
        contentLanguageProvider.overrideWith((ref) => _FixedContentLanguage()),
        analyticsServiceProvider.overrideWithValue(_NoopAnalytics()),
        groupProfileRepositoryProvider.overrideWithValue(
          GroupProfileRepositoryImpl(
            remote: remote,
            store: FakeScreenCacheStore(),
          ),
        ),
        groupMyPermissionProvider.overrideWith(
          () => GroupMyPermissionNotifier(
            (ref, groupId, bind) =>
                GroupPostPermission(groupId: groupId, role: role),
          ),
        ),
        groupPostsProvider.overrideWith(
          (ref, groupId) => GroupPostsNotifier(
            repository: _FakePostRepository(),
            groupId: groupId,
            stored: ConnectPostsPage(
              posts: const [],
              skip: 0,
              limit: 20,
              total: 0,
            ),
          ),
        ),
        unreadSpacesProvider.overrideWithValue(unread),
        if (reports != null)
          groupReportsProvider.overrideWith((ref, groupId) => reports),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home:
              home ??
              GroupProfileScreen(groupId: 'g1', startCollapsed: startCollapsed),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // The body schedules work from deactivate; unmount it inside the test so
  // that timer fires before the framework checks for leaks.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder appBarButton(String tooltip) => find.byTooltip(tooltip);

  double outerOffset(WidgetTester tester) =>
      tester
          .widget<NestedScrollView>(find.byType(NestedScrollView))
          .controller!
          .offset;

  double titleOpacity(WidgetTester tester) =>
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.text('Semkyed').first,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

  setUp(() => remote = _FakeRemote());

  group('app bar', () {
    testWidgets('a member gets prayer requests and chat, no ⋮', (tester) async {
      await pump(tester);

      expect(appBarButton('Prayer requests'), findsOneWidget);
      expect(appBarButton('Chat'), findsOneWidget);
      // The only ⋮ is the round one beside Invite, below the app bar.
      final menu = find.byIcon(AppAssets.dotsThreeVerticalBold);
      expect(find.byIcon(AppAssets.dotsThreeVertical), findsNothing);
      expect(menu, findsOneWidget);
      expect(
        tester.getTopLeft(menu).dy,
        greaterThan(tester.getBottomLeft(appBarButton('Chat')).dy),
      );
      expect(find.byType(ConnectUnreadDot), findsNothing);
      await unmount(tester);
    });

    testWidgets('dots only the button with something unread', (tester) async {
      await pump(tester, unread: const {'g1': SpaceUnread(chat: true)});

      expect(find.byType(ConnectUnreadDot), findsOneWidget);
      expect(
        find.descendant(
          of: appBarButton('Chat'),
          matching: find.byType(ConnectUnreadDot),
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('dots prayer requests when one is unread', (tester) async {
      await pump(tester, unread: const {'g1': SpaceUnread(prayer: true)});

      expect(
        find.descendant(
          of: appBarButton('Prayer requests'),
          matching: find.byType(ConnectUnreadDot),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: appBarButton('Chat'),
          matching: find.byType(ConnectUnreadDot),
        ),
        findsNothing,
      );
      await unmount(tester);
    });

    testWidgets('a visitor gets neither, nor the ⋮', (tester) async {
      remote.isMember = false;
      await pump(tester);

      expect(appBarButton('Prayer requests'), findsNothing);
      expect(appBarButton('Chat'), findsNothing);
      expect(find.byIcon(AppAssets.dotsThreeVertical), findsNothing);
      expect(find.byIcon(AppAssets.dotsThreeVerticalBold), findsNothing);
      await unmount(tester);
    });

    testWidgets('a Page keeps its ⋮ on the app bar', (tester) async {
      remote.groupType = 'PAGE';
      await pump(tester);

      expect(find.byIcon(AppAssets.dotsThreeVertical), findsOneWidget);
      expect(appBarButton('Prayer requests'), findsNothing);
      expect(appBarButton('Chat'), findsNothing);
      await unmount(tester);
    });
  });

  group('member row', () {
    testWidgets('is Invite and ⋮, without the old round chat or prayer', (
      tester,
    ) async {
      await pump(tester);

      final invite = find.text('Invite');
      final menu = find.byIcon(AppAssets.dotsThreeVerticalBold);
      expect(invite, findsOneWidget);
      expect(menu, findsOneWidget);
      // ⋮ sits after Invite on the same row.
      expect(
        tester.getCenter(menu).dx,
        greaterThan(tester.getCenter(invite).dx),
      );
      expect(
        (tester.getCenter(menu).dy - tester.getCenter(invite).dy).abs(),
        lessThan(2),
      );
      // Chat and prayer show once each: on the app bar.
      expect(find.byIcon(AppAssets.chatCircleDots), findsOneWidget);
      expect(find.byIcon(AppAssets.handsPraying), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('⋮ opens the member sheet', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(AppAssets.dotsThreeVerticalBold));
      await tester.pumpAndSettle();

      expect(find.text('Leave space'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('group drawer', () {
    // Opened from drawer:// links; it has no app bar, so the room buttons
    // ride on its handle row.
    Future<void> openDrawer(
      WidgetTester tester, {
      Map<String, SpaceUnread> unread = const {},
    }) async {
      await pump(
        tester,
        unread: unread,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => GroupProfileDrawer.show(context, 'g1'),
                  child: const Text('open'),
                ),
              ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a member gets prayer requests and chat', (tester) async {
      await openDrawer(tester, unread: const {'g1': SpaceUnread(chat: true)});

      expect(appBarButton('Prayer requests'), findsOneWidget);
      expect(appBarButton('Chat'), findsOneWidget);
      expect(
        find.descendant(
          of: appBarButton('Chat'),
          matching: find.byType(ConnectUnreadDot),
        ),
        findsOneWidget,
      );
      // Invite and the ⋮ member menu still show in the body.
      expect(find.text('Invite'), findsOneWidget);
      expect(find.byIcon(AppAssets.dotsThreeVerticalBold), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a visitor gets neither', (tester) async {
      remote.isMember = false;
      await openDrawer(tester);

      expect(appBarButton('Prayer requests'), findsNothing);
      expect(appBarButton('Chat'), findsNothing);
      await unmount(tester);
    });
  });

  group('startCollapsed', () {
    testWidgets('off, the page opens on the header', (tester) async {
      await pump(tester);

      expect(outerOffset(tester), 0);
      expect(titleOpacity(tester), 0);
      await unmount(tester);
    });

    testWidgets('on, the header is scrolled away and the title shows', (
      tester,
    ) async {
      await pump(tester, startCollapsed: true);

      final controller =
          tester
              .widget<NestedScrollView>(find.byType(NestedScrollView))
              .controller!;
      expect(controller.position.maxScrollExtent, greaterThan(0));
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(titleOpacity(tester), 1);
      // The tabs stay pinned under the app bar.
      expect(find.byType(TabBar), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('scrolling up reveals the header again', (tester) async {
      await pump(tester, startCollapsed: true);

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();

      expect(outerOffset(tester), 0);
      expect(find.text('Invite'), findsOneWidget);
      expect(titleOpacity(tester), 0);
      await unmount(tester);
    });

    testWidgets('a header that grows afterwards stays scrolled away', (
      tester,
    ) async {
      final reports = _StubReports();
      await pump(tester, startCollapsed: true, role: 'ADMIN', reports: reports);

      final position =
          tester
              .widget<NestedScrollView>(find.byType(NestedScrollView))
              .controller!
              .position;
      final collapsedEnd = position.maxScrollExtent;
      expect(position.pixels, collapsedEnd);

      // The reports queue answers after the page collapsed: an admin's
      // reports row joins the header, which grows past the old end.
      reports.setTotal(3);
      await tester.pumpAndSettle();

      // The row is in the header, scrolled away above the viewport.
      expect(find.text('Reports', skipOffstage: false), findsOneWidget);
      expect(position.maxScrollExtent, greaterThan(collapsedEnd));
      expect(position.pixels, position.maxScrollExtent);
      expect(titleOpacity(tester), 1);
      await unmount(tester);
    });

    testWidgets('a header that grows after the member scrolled is left alone', (
      tester,
    ) async {
      final reports = _StubReports();
      await pump(tester, startCollapsed: true, role: 'ADMIN', reports: reports);

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();
      expect(outerOffset(tester), 0);

      reports.setTotal(3);
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsOneWidget);
      expect(outerOffset(tester), 0);
      await unmount(tester);
    });
  });
}
