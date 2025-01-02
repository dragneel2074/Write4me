class TextUtils {
  static String trimToWordLimit(String text, {int limit = 500}) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= limit) return text;

    return '${words.take(limit).join(' ')}\n[Note: Text has been trimmed to $limit words due to API limitations]';
  }
}
