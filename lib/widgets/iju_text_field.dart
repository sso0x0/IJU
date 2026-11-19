import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

/// Figma 'Input'. 높이 52, 둥근 14 테두리.
class IjuTextField extends StatelessWidget {
  const IjuTextField({super.key, required this.controller, this.hintText});

  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 16, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textSub),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
