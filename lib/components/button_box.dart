import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:write4me/components/static.dart';

class CopyBox extends StatelessWidget {
  CopyBox({
    super.key,
    required String response,
  }) : _response = response;

  final String _response;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ElevatedButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _response));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard!'),
            ),
          );
        },
        child: const Text('Copy'),
      ),
    );
  }
}

class ResponseBox extends StatelessWidget {
  const ResponseBox({
    super.key,
    required String response,
  }) : _response = response;

  final String _response;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ScreenSize.init(context);
    double myWidgetHeight = ScreenSize.height; // Half of the screen height
    double myWidgetWidth = ScreenSize.width; // 80% of the screen width

    return Column(
      children: [
        CopyBox(response: _response),
         SizedBox(
          height: myWidgetHeight * 0.01,
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(5),
          ),
          child: SelectableText(
            _response,
            style: TextStyle(color: theme.textTheme.titleMedium?.color),
          ),
        ),
      ],
    );
  }
}
