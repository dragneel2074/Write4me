import 'package:flutter/material.dart';

class ResponseBox extends StatelessWidget {
  final String response;

  const ResponseBox({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(response),
    );
  }
}