import '../../core/analysis/face_info.dart';
import '../../core/analysis/photo_score.dart';
import 'group_metadata.dart';

class MediaItem {
  // ===== اطلاعات اصلی =====

  /// مسیر فعلی فایل.
  ///
  /// بعد از Copy یا Move موفقیت‌آمیز
  /// به مسیر مقصد تغییر می‌کند.
  String path;

  final DateTime createdAt;
  final bool isVideo;
  final int fileSize;
  final String fileName;

  // ===== اطلاعات گروه =====

  /// Metadata پوشه‌ای که فایل داخل آن قرار دارد.
  ///
  /// این مقدار هنگام Analyze از
  /// .photonamger.json خوانده می‌شود.
  GroupMetadata? groupMetadata;

  /// مسیر پوشه‌ای که metadata از آن خوانده شده.
  String? metadataDirectory;

  // ===== تحلیل =====

  List<FaceInfo> faces = [];

  PhotoScore? score;

  bool selected = true;

  // ===== وضعیت انتخاب =====

  bool isSelected;

  // ===== نتایج آنالیز =====

  bool analyzed = false;

  double qualityScore;

  double sharpness;

  double blurScore;

  bool isBlurred;

  // ===== اطلاعات چهره =====

  int faceCount;

  int openEyes;

  double faceQuality;

  double largestFaceSize;

  // ===== اطلاعات نور =====

  double brightness;

  double contrast;

  // ===== اطلاعات آینده =====

  double aiScore;

  BigInt? pHash;

  bool eyesOpen = false;

  String analysisMessage;

  MediaItem({
    required this.path,
    required this.createdAt,
    required this.isVideo,
    required this.fileSize,
    required this.fileName,
    this.groupMetadata,
    this.metadataDirectory,
    this.isSelected = true,
    this.analyzed = false,
    this.qualityScore = 0,
    this.sharpness = 0,
    this.blurScore = 0,
    this.isBlurred = false,
    this.faceCount = 0,
    this.openEyes = 0,
    this.faceQuality = 0,
    this.largestFaceSize = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.aiScore = 0,
    this.analysisMessage = '',
  });

  /// تغییر مسیر فایل بعد از Copy یا Move.
  void updatePath(String newPath) {
    path = newPath;
  }
}
