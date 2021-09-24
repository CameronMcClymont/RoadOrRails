import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PostcodeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const PostcodeField({Key? key, required this.controller, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: 'A123BC'),
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [UpperCaseTextFormatter()],
      validator: (value) {
        if (value != null) {
          if (value.isEmpty) {
            return 'Field cannot be empty.';
          }

          String postcode = value.replaceAll(' ', '');
          if (postcode.length >= 5 && postcode.length <= 7) {
            return null;
          }

          return 'Postcode must be 5-7 characters.';
        }
      },
    );
  }
}
