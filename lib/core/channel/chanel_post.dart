class ChannelPost {
  final int id;
  final String title;
  final DateTime date;
  final String preview;

  const ChannelPost({
    required this.id,
    required this.title,
    required this.date,
    this.preview = '',
  });
}
