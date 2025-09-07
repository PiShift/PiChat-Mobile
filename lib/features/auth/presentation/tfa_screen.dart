import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otp_pin_field/otp_pin_field.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/network/error_handler.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/auth_repository.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';
import 'package:pichat/shared/base/BaseButton.dart';
import 'package:pichat/shared/base/BaseInput.dart';

class TfaScreen extends ConsumerStatefulWidget {
  const TfaScreen({super.key});

  @override
  ConsumerState<TfaScreen> createState() => _TfaScreenState();
}

class _TfaScreenState extends ConsumerState<TfaScreen> {
  final _codeCtrl = TextEditingController();
  final _otpPinFieldController = GlobalKey<OtpPinFieldState>();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    final tfaToken = ref.watch(tfaTokenProvider);
    final loginState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(mediaQuery.width * 0.01),
                width: mediaQuery.width * 0.429,
                child: Hero(
                  tag: "logoHero",
                  child: Image.asset("assets/images/logo.png"),
                ),
              ),
              SizedBox(height: mediaQuery.height * 0.15),
              // BaseInput(
              //     textController: _codeCtrl,
              //     label: Text("2FA Code".tr()),
              //     validator: (v) => v.isEmpty ? 'Enter 2FA code'.tr() : null,
              //     hint: 'Enter your 2FA code'.tr(),
              //     inputAction: TextInputAction.done,
              //     inputType: TextInputType.number,
              //     autoFocus: true,
              //     borderColor: AppColors.primary,
              //   maxLength: 6,
              // ),
              Text("Enter your 2FA code".tr()),
              const SizedBox(height: 8),
              OtpPinField(
                key: _otpPinFieldController,
                maxLength: 6,
                autoFillEnable: true,
                textInputAction: TextInputAction.done,
                otpPinFieldStyle: OtpPinFieldStyle(
                  activeFieldBorderColor: AppColors.primary,
                ),
                otpPinFieldDecoration: OtpPinFieldDecoration.defaultPinBoxDecoration,
                onChange: (value) {
                  _codeCtrl.text = value;
                },
                onSubmit: (value) {
                  _codeCtrl.text = value;
                },
              ),
              const SizedBox(height: 20),
              BaseButton(
                onTap: loading || tfaToken == null || _codeCtrl.text.length < 6 ? null : () async {
                  setState(() => loading = true);
                  try {
                    await ref
                        .read(authControllerProvider.notifier)
                        .verifyTfa(tfaToken, _codeCtrl.text);

                    // clear temporary token
                    ref.read(tfaTokenProvider.notifier).setToken(null);

                  } catch (e) {
                    // print('verifyTfa FAILED: error=$e');
                    // print('providers at failure: tfa=${ref.read(tfaTokenProvider)}, token=${ref.read(authTokenProvider)}, org=${ref.read(organizationProvider)}');
                    final msg = ErrorHandler.getErrorMessage(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                    _codeCtrl.clear();
                    _otpPinFieldController.currentState?.clearOtp();
                    if(e is DioException && e.response?.statusCode == 401) {
                      // for other errors, clear TFA token and go back to login
                      ref.read(tfaTokenProvider.notifier).setToken(null);
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  } finally {
                    setState(() => loading = false);
                  }
                },
                text: "Verify".tr(),
                isLoading: loading,
                disabled: loading || tfaToken == null || _codeCtrl.text.length < 6
              ),
              if (loginState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    loginState.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
