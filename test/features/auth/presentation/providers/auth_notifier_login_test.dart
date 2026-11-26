import 'dart:async';
import 'dart:convert';

import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/auth/domain/entities/auth_credentials.dart';
import 'package:flutter_pecha/features/auth/domain/entities/phone_code_start.dart';
import 'package:flutter_pecha/features/auth/domain/entities/user.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/clear_guest_mode_and_onboarding_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/clear_guest_mode_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/continue_as_guest_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/get_credentials_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/has_valid_credentials_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/initialize_auth_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/is_guest_mode_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_datasource_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';

import '../../../../core/analytics/recording_analytics_service.dart';
import '../../../reader/fakes/fake_local_storage.dart';
import 'auth_notifier_test.mocks.dart';

AuthCredentials _credentials(String userId) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return AuthCredentials(
    accessToken: '${seg({'alg': 'HS256'})}.${seg({'sub': userId})}.sig',
    tokenType: 'Bearer',
    expiresIn: 3600,
    obtainedAt: DateTime.now(),
    refreshToken: 'refresh',
  );
}

/// The repository under the real use cases. Each sign-in call answers with
/// the value set for it.
class _Repository implements AuthRepository {
  @override
  void cancelPhoneSignIn() {}

  bool legacySessionRemoved = false;
  bool storedSession = false;
  bool guest = false;

  /// When set, a Google login waits for it before answering.
  Completer<void>? googleHold;

  Either<Failure, AuthCredentials> google = const Left(
    UnknownFailure('not set'),
  );
  Either<Failure, PhoneCodeStart> phoneCode = const Left(
    UnknownFailure('not set'),
  );
  Either<Failure, AuthCredentials> phoneLogin = const Left(
    UnknownFailure('not set'),
  );

  final List<String> requestedNumbers = [];
  int logouts = 0;

  @override
  Future<Either<Failure, void>> initialize() async => const Right(null);

  @override
  bool takeLegacySessionRemoved() {
    final removed = legacySessionRemoved;
    legacySessionRemoved = false;
    return removed;
  }

  @override
  Future<Either<Failure, bool>> hasValidCredentials() async =>
      Right(storedSession);

  @override
  Future<Either<Failure, bool>> isGuestMode() async => Right(guest);

  @override
  Future<Either<Failure, void>> clearGuestMode() async => const Right(null);

  @override
  Future<Either<Failure, void>> localLogout() async {
    logouts++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, AuthCredentials>> loginWithGoogle() async {
    await googleHold?.future;
    return google;
  }

  @override
  Future<Either<Failure, PhoneCodeStart>> requestPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    requestedNumbers.add(phoneNumber);
    return phoneCode;
  }

  @override
  Future<Either<Failure, AuthCredentials>> loginWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async => phoneLogin;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Analytics extends RecordingAnalyticsService {
  final List<String> identified = [];
  int resets = 0;

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  }) async => identified.add(userId);

  @override
  Future<void> reset() async => resets++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  provideDummy<Either<Failure, bool>>(const Left(UnknownFailure('dummy')));
  provideDummy<Either<Failure, User>>(const Left(UnknownFailure('dummy')));

  late _Repository repository;
  late _Analytics analytics;
  late FakeLocalStorage storage;
  late ProviderContainer container;

  /// Builds the notifier over [repository] and waits for the launch restore.
  Future<AuthNotifier> start() async {
    final connectivity = MockConnectivityService();
    when(
      connectivity.onConnectivityChanged,
    ).thenAnswer((_) => const Stream<bool>.empty());
    final onboarding = MockOnboardingRepositoryImpl();
    when(
      onboarding.isOnboardingCompleted(),
    ).thenAnswer((_) async => const Right(true));
    final getUser = MockGetCurrentUserUseCase();
    when(
      getUser(any),
    ).thenAnswer((_) async => const Left(NetworkFailure('not needed here')));

    final isGuest = IsGuestModeUseCase(repository);
    final clearGuest = ClearGuestModeUseCase(repository);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        localStorageServiceProvider.overrideWithValue(storage),
        connectivityServiceProvider.overrideWithValue(connectivity),
        analyticsServiceProvider.overrideWithValue(analytics),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        userProvider.overrideWith(
          (ref) => UserNotifier(
            getCurrentUserUseCase: getUser,
            updateUserInfoUseCase: MockUpdateUserInfoUseCase(),
            updateUsernameUseCase: MockUpdateUsernameUseCase(),
            uploadAvatarUseCase: MockUploadAvatarUseCase(),
            localStorageService: storage,
          ),
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: LoginUseCase(repository),
            initializeAuthUseCase: InitializeAuthUseCase(repository),
            hasValidCredentialsUseCase: HasValidCredentialsUseCase(repository),
            getCredentialsUseCase: GetCredentialsUseCase(repository),
            continueAsGuestUseCase: ContinueAsGuestUseCase(repository),
            isGuestModeUseCase: isGuest,
            clearGuestModeUseCase: clearGuest,
            localLogoutUseCase: LogoutUseCase(repository),
            clearGuestModeAndOnboardingUseCase:
                ClearGuestModeAndOnboardingUseCase(clearGuest, isGuest),
            ref: ref,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authProvider.notifier);
    if (notifier.state.isLoading) {
      await notifier.stream
          .firstWhere((s) => !s.isLoading)
          .timeout(const Duration(seconds: 2));
    }
    return notifier;
  }

  List<String> failedLogins() => [
    for (final e in analytics.events)
      if (e.name == AnalyticsEvents.authLoginFailed) e.name,
  ];

  TrackedEvent succeededLogin() => analytics.events.singleWhere(
    (e) => e.name == AnalyticsEvents.authLoginSucceeded,
  );

  setUp(() {
    repository = _Repository();
    analytics = _Analytics();
    // A known install skips the Android fresh-install credential clear.
    storage = FakeLocalStorage()..values[StorageKeys.firstLaunch] = true;
  });

  group('updating from an Auth0 build', () {
    test('lands on login and drops the old analytics identity', () async {
      repository.legacySessionRemoved = true;

      final notifier = await start();

      expect(notifier.state.isLoggedIn, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(analytics.resets, 1);
    });

    test('a normal launch resets nothing', () async {
      await start();
      expect(analytics.resets, 0);
    });

    test('the same account keeps the id its local data is under', () async {
      // What the cleanup remembered: the Auth0 subject this account's mala
      // counts, timer stops and plan actions are stored under.
      storage.values[StorageKeys.legacyAuth0UserId] = 'google-oauth2|1';
      storage.values[StorageKeys.legacyAuth0BackendUserId] = 'backend-user-1';
      repository.google = Right(_credentials('backend-user-1'));
      final notifier = await start();

      await notifier.login(connection: 'google');
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(storage.values[StorageKeys.currentUserId], 'google-oauth2|1');
      // The same person in analytics too.
      expect(analytics.identified, ['google-oauth2|1']);
    });

    test('another account on that phone gets its own id', () async {
      storage.values[StorageKeys.legacyAuth0UserId] = 'google-oauth2|1';
      storage.values[StorageKeys.legacyAuth0BackendUserId] = 'backend-user-1';
      repository.google = Right(_credentials('backend-user-9'));
      final notifier = await start();

      await notifier.login(connection: 'google');
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(storage.values[StorageKeys.currentUserId], 'backend-user-9');
      // The first account's id is still there for when it returns.
      expect(storage.values[StorageKeys.legacyAuth0UserId], 'google-oauth2|1');
    });
  });

  group('Google and Apple sign in where the person is', () {
    test('no splash: the launch flag stays off while the login runs', () async {
      repository.googleHold = Completer<void>();
      repository.google = Right(_credentials('backend-user-1'));
      final notifier = await start();

      final login = notifier.login(connection: 'google');
      await Future<void>.delayed(Duration.zero);

      // The route guard shows the splash on isLoading. A sign-in must not
      // set it, or the screen the person is on is lost.
      expect(notifier.state.isSigningIn, isTrue);
      expect(notifier.state.isLoading, isFalse);

      repository.googleHold!.complete();
      await login;
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(notifier.state.isSigningIn, isFalse);
    });

    test('a guest stays a guest, on their screen, until signed in', () async {
      repository.guest = true;
      repository.googleHold = Completer<void>();
      repository.google = Right(_credentials('backend-user-1'));
      final notifier = await start();
      expect(notifier.state.isGuest, isTrue);

      final login = notifier.login(
        connection: 'google',
        source: AuthSource.loginDrawer,
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isGuest, isTrue);
      expect(notifier.state.isLoggedIn, isTrue);

      repository.googleHold!.complete();
      await login;
      await notifier.stream.firstWhere((s) => !s.isGuest);

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.isSigningIn, isFalse);
    });

    test('a guest who cancels is still a guest, with the spinner gone', () async {
      repository.guest = true;
      repository.google = const Left(
        LoginFailure(
          'Google login failed: AuthException: Login was cancelled by user',
          LoginFailureReason.cancelled,
        ),
      );
      final notifier = await start();

      await notifier.login(connection: 'google');

      expect(notifier.state.isGuest, isTrue);
      expect(notifier.state.isSigningIn, isFalse);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('phone sign-in', () {
    test('Android reading the SMS signs in from the code screen', () async {
      final sms = Completer<AuthCredentials?>();
      repository.phoneCode = Right(
        PhoneCodeStart.codeSent(verificationId: 'v-1', autoSignIn: sms.future),
      );
      final notifier = await start();

      await notifier.requestPhoneCode(
        '+919876543210',
        source: AuthSource.loginPage,
      );
      expect(notifier.state.isLoggedIn, isFalse);

      sms.complete(_credentials('backend-user-8'));
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(storage.values[StorageKeys.currentUserId], 'backend-user-8');
      expect(succeededLogin().properties, {
        AnalyticsProperties.method: 'sms',
        AnalyticsProperties.source: 'login_page',
        AnalyticsProperties.isNewUser: false,
      });
    });

    test('no SMS read: the code screen just keeps waiting', () async {
      repository.phoneCode = Right(
        PhoneCodeStart.codeSent(
          verificationId: 'v-1',
          autoSignIn: Future.value(),
        ),
      );
      final notifier = await start();

      await notifier.requestPhoneCode('+919876543210');
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isLoggedIn, isFalse);
    });

    test('a sent code is handed to the screen without signing in', () async {
      repository.phoneCode = const Right(
        PhoneCodeStart.codeSent(verificationId: 'v-1', resendToken: 3),
      );
      final notifier = await start();

      final result = await notifier.requestPhoneCode(
        '+919876543210',
        source: AuthSource.loginPage,
      );

      final start_ = result.getOrElse((_) => throw StateError('failed'));
      expect(start_.verificationId, 'v-1');
      expect(start_.resendToken, 3);
      expect(repository.requestedNumbers, ['+919876543210']);
      expect(notifier.state.isLoggedIn, isFalse);
      // The phone screen shows its own progress.
      expect(notifier.state.isLoading, isFalse);
    });

    test('a refused number is returned and reported', () async {
      repository.phoneCode = const Left(
        LoginFailure(
          'Phone login failed: AuthException: Sign-in failed '
          '(invalid-phone-number)',
          LoginFailureReason.invalidPhoneNumber,
        ),
      );
      final notifier = await start();

      final result = await notifier.requestPhoneCode('+1');

      expect(
        result.fold((f) => f.reason, (_) => null),
        LoginFailureReason.invalidPhoneNumber,
      );
      expect(failedLogins(), hasLength(1));
      expect(notifier.state.isLoggedIn, isFalse);
    });

    test('the right code signs in under the backend user id', () async {
      repository.phoneLogin = Right(_credentials('backend-user-1'));
      final notifier = await start();

      final failure = await notifier.verifyPhoneCode(
        verificationId: 'v-1',
        smsCode: '123456',
        source: AuthSource.loginDrawer,
      );

      expect(failure, isNull);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.isGuest, isFalse);
      expect(storage.values[StorageKeys.currentUserId], 'backend-user-1');
      expect(analytics.identified, ['backend-user-1']);
      // Reported under the method name the Auth0 builds used.
      expect(succeededLogin().properties, {
        AnalyticsProperties.method: 'sms',
        AnalyticsProperties.source: 'login_drawer',
        AnalyticsProperties.isNewUser: false,
      });
    });

    test('a wrong code is returned for the screen to word', () async {
      repository.phoneLogin = const Left(
        LoginFailure('Phone login failed: x', LoginFailureReason.invalidCode),
      );
      final notifier = await start();

      final failure = await notifier.verifyPhoneCode(
        verificationId: 'v-1',
        smsCode: '000000',
      );

      expect(failure?.reason, LoginFailureReason.invalidCode);
      expect(notifier.state.isLoggedIn, isFalse);
      // The phone screen shows it; the login page underneath must not too.
      expect(notifier.state.loginError, isNull);
    });

    test('a number Android verified without a code signs in at once',
        () async {
      repository.phoneCode = Right(
        PhoneCodeStart.signedIn(_credentials('backend-user-2')),
      );
      final notifier = await start();

      final result = await notifier.requestPhoneCode('+919876543210');

      expect(result.isRight(), isTrue);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(storage.values[StorageKeys.currentUserId], 'backend-user-2');
    });
  });

  group('a first-time account goes to onboarding', () {
    /// A new account: the backend says onboarding is not done yet.
    Future<AuthNotifier> startNewAccount() async {
      final notifier = await start();
      when(
        container.read(onboardingRepositoryProvider).isOnboardingCompleted(),
      ).thenAnswer((_) async => const Right(false));
      return notifier;
    }

    test('after a phone code', () async {
      repository.phoneLogin = Right(_credentials('backend-user-3'));
      final notifier = await startNewAccount();

      final failure = await notifier.verifyPhoneCode(
        verificationId: 'v-1',
        smsCode: '123456',
      );

      // No name is asked for during sign-in; the route guard sends an
      // account with onboarding still to do there, where a phone account is
      // asked what to call it.
      expect(failure, isNull);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasCompletedOnboarding, isFalse);
    });

    test('after Google or Apple', () async {
      repository.google = Right(_credentials('backend-user-4'));
      final notifier = await startNewAccount();

      await notifier.login(connection: 'google');
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(notifier.state.hasCompletedOnboarding, isFalse);
    });

    test('a returning account skips it', () async {
      repository.google = Right(_credentials('backend-user-5'));
      final notifier = await start();

      await notifier.login(connection: 'google');
      await notifier.stream.firstWhere((s) => s.isLoggedIn);

      expect(notifier.state.hasCompletedOnboarding, isTrue);
    });
  });

  test('the login page is told why a Google login failed, until the next try',
      () async {
    repository.google = const Left(
      LoginFailure('Google login failed: x', LoginFailureReason.network),
    );
    final notifier = await start();

    await notifier.login(connection: 'google');
    expect(notifier.state.loginError, LoginFailureReason.network);

    final states = <LoginFailureReason?>[];
    final remove = notifier.addListener(
      (s) => states.add(s.loginError),
      fireImmediately: false,
    );
    addTearDown(remove);
    await notifier.login(connection: 'google');

    // Cleared while the retry runs, set again when it fails.
    expect(states, [null, LoginFailureReason.network]);
  });

  test('a failed Google login is reported and leaves the login page up',
      () async {
    repository.google = const Left(
      LoginFailure(
        'Google login failed: AuthException: Login was cancelled by user',
        LoginFailureReason.cancelled,
      ),
    );
    final notifier = await start();

    await notifier.login(connection: 'google', source: AuthSource.loginPage);

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.isLoggedIn, isFalse);
    // For the login page to word; a cancel words to nothing.
    expect(notifier.state.loginError, LoginFailureReason.cancelled);
    final failed = analytics.events.singleWhere(
      (e) => e.name == AnalyticsEvents.authLoginFailed,
    );
    expect(failed.properties[AnalyticsProperties.reasonCode], 'user_cancelled');
  });
}
