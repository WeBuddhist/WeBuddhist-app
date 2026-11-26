import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_steps_provider.dart';
import 'package:flutter_pecha/features/onboarding/presentation/utils/onboarding_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a phone account sets its name after the welcome page', () {
    expect(onboardingStepsFor('phone'), [
      OnboardingStep.welcome,
      OnboardingStep.profile,
      OnboardingStep.language,
      OnboardingStep.tradition,
      OnboardingStep.finish,
    ]);
  });

  test('other accounts skip the profile page', () {
    for (final signInMethod in ['google', 'apple', 'sms', null]) {
      expect(
        onboardingStepsFor(signInMethod),
        isNot(contains(OnboardingStep.profile)),
        reason: '$signInMethod',
      );
    }
  });
}
