import 'package:flutter_pecha/core/storage/preferences_service.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/onboarding/presentation/utils/onboarding_analytics.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The onboarding pages for the signed-in account, in order.
///
/// A phone sign-in shares no name, so a phone account is created with a
/// placeholder name and a generated username; phone accounts pick their own
/// display name and username on an extra [OnboardingStep.profile] page.
/// Accounts that already finished onboarding never see it.
final onboardingStepsProvider = Provider.autoDispose<List<OnboardingStep>>((
  ref,
) {
  // Stored at sign-in, before auth state flips, so it is set by the time
  // onboarding opens.
  final signInMethod = SharedPreferencesService.instance.getSync<String>(
    StorageKeys.signInMethod,
  );
  return onboardingStepsFor(signInMethod);
});

/// [signInMethod] is what was stored under [StorageKeys.signInMethod] at
/// sign-in: `google`, `apple` or `phone`.
List<OnboardingStep> onboardingStepsFor(String? signInMethod) {
  final isPhoneAccount = signInMethod == 'phone';
  return [
    OnboardingStep.welcome,
    if (isPhoneAccount) OnboardingStep.profile,
    OnboardingStep.language,
    OnboardingStep.tradition,
    OnboardingStep.finish,
  ];
}
