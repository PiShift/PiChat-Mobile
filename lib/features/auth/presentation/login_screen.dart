import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';
import 'package:pichat/shared/base/BaseButton.dart';
import 'package:pichat/shared/base/BaseInput.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool revealPassword = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    final authState = ref.watch(authProvider);
    final loginState = ref.watch(authControllerProvider);
    // Listen to login state changes
    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (e, st) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        },
      );
    });


    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
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
                BaseInput(
                  textController: _emailCtrl,
                  label: Text('Email'.tr()),
                  validator: (v) => v.isEmpty ? 'Enter email' : null,
                  hint: 'Enter your email'.tr(),
                  inputAction: TextInputAction.next,
                  inputType: TextInputType.emailAddress,
                  autoFocus: true,
                  borderColor: AppColors.primary
                ),
                const SizedBox(height: 12),
                BaseInput(
                  textController: _passwordCtrl,
                  hint: "Enter your password".tr(),
                  inputAction: TextInputAction.done,
                  inputType: TextInputType.visiblePassword,
                  isObscure: !revealPassword,
                  borderColor: AppColors.primary,
                  suffixIcon: IconButton(
                    icon: Icon(
                      revealPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: revealPassword ? AppColors.primary : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        revealPassword = !revealPassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                BaseButton(
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      ref
                          .read(authControllerProvider.notifier)
                          .login(_emailCtrl.text, _passwordCtrl.text);
                    }
                  },
                  text: 'Login'.tr(),
                  isLoading: loginState.isLoading,
                  disabled: loginState.isLoading,
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
      ),
    );
  }
}
