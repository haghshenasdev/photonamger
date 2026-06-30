import '../../core/analysis/face_info.dart';
import '../../core/analysis/photo_score.dart';

class MediaItem {
  // ===== اطلاعات اصلی =====

  final String path;

  final DateTime createdAt;

  final bool isVideo;

  final int fileSize;

  final String fileName;

  List<FaceInfo> faces = [];
  PhotoScore? score;
  bool selected=true;

  // ===== وضعیت انتخاب =====

  /// آیا برای نگهداری انتخاب شده است؟
  bool isSelected;

  // ===== نتایج آنالیز =====

  /// آیا این فایل قبلاً آنالیز شده؟
  bool analyzed = false;

  /// امتیاز نهایی کیفیت (0..100)
  double qualityScore;

  /// میزان شارپنس تصویر
  double sharpness;

  /// میزان تاری
  double blurScore;

  /// آیا تصویر تار است؟
  bool isBlurred;

  // ===== اطلاعات چهره =====

  /// تعداد چهره‌های پیدا شده
  int faceCount;

  /// تعداد چشم‌های باز
  int openEyes;

  /// میانگین کیفیت چهره‌ها
  double faceQuality;

  /// بزرگترین چهره
  double largestFaceSize;

  // ===== اطلاعات نور =====

  /// روشنایی تصویر
  double brightness;

  /// کنتراست
  double contrast;

  // ===== اطلاعات آینده =====

  /// امتیاز پیشنهادی موتور هوشمند
  double aiScore;

  BigInt? pHash;

  bool eyesOpen = false;

  /// دلیل انتخاب یا رد شدن
  String analysisMessage;

  MediaItem({
    required this.path,
    required this.createdAt,
    required this.isVideo,
    required this.fileSize,
    required this.fileName,

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
}
