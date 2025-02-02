import 'package:flutter/material.dart';

@immutable
class ChatThemeExtension extends ThemeExtension<ChatThemeExtension> {
  final Color userBubbleColor;
  final Color botBubbleColor;
  final Color userTextColor;
  final Color botTextColor;
  final Color bubbleIconColor;
  final Color bubbleIconBackgroundColor;

  const ChatThemeExtension({
    required this.userBubbleColor,
    required this.botBubbleColor,
    required this.userTextColor,
    required this.botTextColor,
    required this.bubbleIconColor,
    required this.bubbleIconBackgroundColor,
  });

  @override
  ThemeExtension<ChatThemeExtension> copyWith({
    Color? userBubbleColor,
    Color? botBubbleColor,
    Color? userTextColor,
    Color? botTextColor,
    Color? bubbleIconColor,
    Color? bubbleIconBackgroundColor,
  }) {
    return ChatThemeExtension(
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      botBubbleColor: botBubbleColor ?? this.botBubbleColor,
      userTextColor: userTextColor ?? this.userTextColor,
      botTextColor: botTextColor ?? this.botTextColor,
      bubbleIconColor: bubbleIconColor ?? this.bubbleIconColor,
      bubbleIconBackgroundColor: bubbleIconBackgroundColor ?? this.bubbleIconBackgroundColor,
    );
  }

  @override
  ThemeExtension<ChatThemeExtension> lerp(
    ThemeExtension<ChatThemeExtension>? other,
    double t,
  ) {
    if (other is! ChatThemeExtension) {
      return this;
    }
    return ChatThemeExtension(
      userBubbleColor: Color.lerp(userBubbleColor, other.userBubbleColor, t)!,
      botBubbleColor: Color.lerp(botBubbleColor, other.botBubbleColor, t)!,
      userTextColor: Color.lerp(userTextColor, other.userTextColor, t)!,
      botTextColor: Color.lerp(botTextColor, other.botTextColor, t)!,
      bubbleIconColor: Color.lerp(bubbleIconColor, other.bubbleIconColor, t)!,
      bubbleIconBackgroundColor: Color.lerp(bubbleIconBackgroundColor, other.bubbleIconBackgroundColor, t)!,
    );
  }
} 