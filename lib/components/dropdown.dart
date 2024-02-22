import 'package:flutter/material.dart';

class SourceDropdown extends StatelessWidget {
  const SourceDropdown({
    super.key,
    required this.selectedSource,
    required this.onChanged,
    required this.sources,
  });

  final String selectedSource;
  final ValueChanged<String?> onChanged;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final Map<String, String> sourceDetails = {
      "Source 1": "Great & Censored",
      "Source 2": "Good & Uncensored",
      "Source 3": "Good & Censored",
    };

    // Get the theme data from the context
    ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: theme.canvasColor, // Use theme canvas color
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: theme.dividerColor, // Use theme divider color
          width: 2.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSource,
          icon: Icon(
            Icons.arrow_downward,
            color: theme.iconTheme.color, // Use theme icon color
            size: 18,
          ),
          elevation: 5,
          style: theme.textTheme.titleMedium, // Use theme text style
          onChanged: onChanged,
          items: sources.map<DropdownMenuItem<String>>((String value) {
            String detailedText = "$value (${sourceDetails[value]})";
            return DropdownMenuItem<String>(
              value: value,
              child: Container(
                padding: const EdgeInsets.all(2.0),
                child: Text(
                  detailedText,
                  style: TextStyle(color: theme.textTheme.titleMedium?.color), // Use theme text color
                ),
              ),
            );
          }).toList(),
          dropdownColor: theme.cardColor, // Use theme card color for dropdown background
        ),
      ),
    );
  }
}
