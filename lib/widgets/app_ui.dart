import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tiêu đề nhóm form: hierarchy rõ, cách field 8pt.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// Banner trạng thái (thành công / lỗi), tương phản ổn định.
class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    super.key,
    required this.child,
    required this.positive,
  });

  final Widget child;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey<bool>(positive),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: positive
              ? AppSemantic.successBackground(context)
              : AppSemantic.errorBackground(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: (positive
                    ? AppSemantic.successForeground(context)
                    : AppSemantic.errorForeground(context))
                .withValues(alpha: 0.35),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: positive
                ? AppSemantic.successForeground(context)
                : AppSemantic.errorForeground(context),
            height: 1.5,
          ),
          child: child,
        ),
      ),
    );
  }
}
