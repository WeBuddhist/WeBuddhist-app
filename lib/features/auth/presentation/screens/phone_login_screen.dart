import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/domain/failures/login_failure.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/auth_analytics.dart';
import 'package:flutter_pecha/features/auth/presentation/utils/login_failure_text.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_form_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the E.164 number for a typed [input] and a country [dialCode]
/// (digits, no plus). A number typed with its own `+` is taken as complete.
/// Returns null when the result cannot be a phone number.
String? composeE164(String dialCode, String input) {
  final trimmed = input.trim();
  final String digits;
  if (trimmed.startsWith('+')) {
    digits = trimmed.replaceAll(RegExp(r'\D'), '');
  } else {
    // National numbers are often written with a leading trunk zero.
    final national = trimmed
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (national.isEmpty) return null;
    digits = '${dialCode.replaceAll(RegExp(r'\D'), '')}$national';
  }
  // E.164: up to 15 digits, and no country has numbers shorter than 8 with
  // its code.
  if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) {
    return null;
  }
  return '+$digits';
}

/// Phone sign-in: enter a number, then the code Firebase texts to it.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key, required this.source});

  /// Where the login started, for analytics.
  final AuthSource source;

  /// Opens above everything, including the login drawer's sheet.
  static Future<void> open(BuildContext context, {required AuthSource source}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'phone_login'),
        builder: (_) => PhoneLoginScreen(source: source),
      ),
    );
  }

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen>
    with CloseWhenSignedIn {
  /// How long before the code can be asked for again.
  static const _resendWait = 30;
  static const _codeLength = 6;

  final _numberController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  late Country _country;

  /// Set once a code has gone out; the screen then asks for the code.
  String? _verificationId;
  int? _resendToken;
  String? _sentTo;

  bool _busy = false;
  LoginFailureReason? _error;

  Timer? _resendTimer;
  int _resendIn = 0;

  /// Held from [initState]: [dispose] needs it, and `ref` is not for use
  /// there.
  late final AuthNotifier _auth;

  @override
  void initState() {
    super.initState();
    _auth = ref.read(authProvider.notifier);
    // Start from the phone's region; the app language says nothing about
    // where a number is from.
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '';
    _country = Country.tryParse(region) ?? Country.parse('IN');
  }

  @override
  void dispose() {
    // Leaving with a code requested: Android must not finish that sign-in
    // after the person has gone. Read here, before super.dispose().
    if (_verificationId != null) _auth.cancelPhoneSignIn();
    _resendTimer?.cancel();
    _numberController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendWait);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy) return;
    final phoneNumber =
        resend
            ? _sentTo
            : composeE164(_country.phoneCode, _numberController.text);
    if (phoneNumber == null) {
      setState(() => _error = LoginFailureReason.invalidPhoneNumber);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(authProvider.notifier)
        .requestPhoneCode(
          phoneNumber,
          resendToken: resend ? _resendToken : null,
          source: widget.source,
        );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _error = failure.reason;
      }),
      (start) {
        // Verified without a code: signed in, and the screen is closing.
        if (start.isSignedIn) return;
        setState(() {
          _busy = false;
          _verificationId = start.verificationId;
          _resendToken = start.resendToken;
          _sentTo = phoneNumber;
          _codeController.clear();
        });
        _startResendCountdown();
        _codeFocus.requestFocus();
      },
    );
  }

  Future<void> _verify() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (_busy || verificationId == null) return;
    if (code.length != _codeLength) {
      setState(() => _error = LoginFailureReason.invalidCode);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(authProvider.notifier)
        .verifyPhoneCode(
          verificationId: verificationId,
          smsCode: code,
          source: widget.source,
        );
    if (!mounted) return;
    // Signed in: the screen is closing, keep the spinner until it does.
    if (failure == null) return;
    setState(() {
      _busy = false;
      _error = failure.reason;
    });
  }

  void _changeNumber() {
    // The code for the old number may still be read by Android; the person
    // has moved on from it.
    _auth.cancelPhoneSignIn();
    _resendTimer?.cancel();
    setState(() {
      _verificationId = null;
      _resendToken = null;
      _sentTo = null;
      _error = null;
      _resendIn = 0;
      _codeController.clear();
    });
  }

  void _pickCountry() {
    final theme = Theme.of(context);
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: theme.scaffoldBackgroundColor,
        textStyle: theme.textTheme.bodyLarge,
        searchTextStyle: theme.textTheme.bodyLarge,
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: loginFieldDecoration(
          context,
          hintText: context.l10n.phone_login_country_search,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      onSelect: (country) => setState(() => _country = country),
    );
  }

  @override
  Widget build(BuildContext context) {
    closeWhenSignedIn();
    final l10n = context.l10n;
    final error = _error == null ? null : loginFailureText(l10n, _error!);
    final askingForCode = _verificationId != null;

    // No leaving while a code is being sent or checked: the answer would
    // still arrive, and could sign in someone who thought they had backed out.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    askingForCode
                        ? _codeStep(context, error)
                        : _numberStep(context, error),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _numberStep(BuildContext context, String? error) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      LoginFormHeader(
        title: l10n.phone_login_title,
        subtitle: l10n.phone_login_subtitle,
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _numberController,
        enabled: !_busy,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          LengthLimitingTextInputFormatter(20),
        ],
        style: theme.textTheme.titleMedium,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _sendCode(),
        decoration: loginFieldDecoration(
          context,
          hintText: l10n.phone_login_number_hint,
          errorText: error,
          prefixIcon: InkWell(
            onTap: _busy ? null : _pickCountry,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _country.flagEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${_country.phoneCode}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      LoginFormButton(
        label: l10n.phone_login_send_code,
        busy: _busy,
        onPressed: _sendCode,
      ),
    ];
  }

  List<Widget> _codeStep(BuildContext context, String? error) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canResend = _resendIn <= 0 && !_busy;
    return [
      LoginFormHeader(
        title: l10n.phone_login_code_title,
        subtitle: l10n.phone_login_code_subtitle(_sentTo ?? ''),
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _codeController,
        focusNode: _codeFocus,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_codeLength),
        ],
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
        onChanged: (value) {
          if (_error != null) setState(() => _error = null);
          if (value.length == _codeLength) _verify();
        },
        onSubmitted: (_) => _verify(),
        decoration: loginFieldDecoration(
          context,
          hintText: l10n.phone_login_code_hint,
          errorText: error,
        ).copyWith(
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            letterSpacing: 0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
      const SizedBox(height: 24),
      LoginFormButton(
        label: l10n.phone_login_verify,
        busy: _busy,
        onPressed: _verify,
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: canResend ? () => _sendCode(resend: true) : null,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
          child: Text(
            _resendIn > 0
                ? l10n.phone_login_resend_in(_resendIn)
                : l10n.phone_login_resend,
          ),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _changeNumber,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
          child: Text(l10n.phone_login_change_number),
        ),
      ),
    ];
  }
}
