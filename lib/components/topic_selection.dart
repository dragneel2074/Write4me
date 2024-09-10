import 'package:flutter/material.dart';

class TopicSection extends StatelessWidget {
  final TextEditingController controller;

  const TopicSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start Writing',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your question',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
      ],
    );
  }
}