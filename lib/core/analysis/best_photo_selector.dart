import '../../ui/models/duplicate_group.dart';
import '../../ui/models/media_item.dart';

class BestPhotoSelector {
  void selectDuplicateMasters(List<DuplicateGroup> groups) {
    for (final group in groups) {
      double best = -999999;

      int index = 0;

      for (int i = 0; i < group.items.length; i++) {
        final s = _smartScore(group.items[i]);

        if (s > best) {
          best = s;

          index = i;
        }
      }

      group.selectedIndex = index;
    }
  }

  void sortDuplicates(List<DuplicateGroup> groups) {
    for (final group in groups) {
      group.items.sort((a, b) {
        final sa = a.score?.total ?? 0;

        final sb = b.score?.total ?? 0;

        return sb.compareTo(sa);
      });

      group.selectedIndex = 0;
    }
  }

  double _smartScore(MediaItem item) {
    if (item.score == null) {
      return 0;
    }

    double score = item.score!.total;

    //----------------------------------
    // 1- Blur
    //----------------------------------

    if (item.blurScore < 0.30) {
      score -= 100;
    } else if (item.blurScore < 0.50) {
      score -= 20;
    }

    //----------------------------------
    // 2- بدون چهره
    //----------------------------------

    if (item.faces.isEmpty) {
      score -= 5;
    }

    //----------------------------------
    // 3- فقط سه چهره بزرگ
    //----------------------------------

    final faces = [...item.faces];

    faces.sort((a, b) => b.faceArea.compareTo(a.faceArea));

    final topFaces = faces.take(3);

    //----------------------------------
    // 4- چشم بسته
    //----------------------------------

    for (final face in topFaces) {
      if (face.leftEyeOpenProbability < 0.5) {
        score -= 10;
      }

      if (face.rightEyeOpenProbability < 0.5) {
        score -= 10;
      }
    }

    //----------------------------------
    // 5- نیم رخ
    //----------------------------------

    for (final face in topFaces) {
      if (face.headEulerY.abs() > 20) {
        score -= 5;
      }

      if (face.headEulerZ.abs() > 20) {
        score -= 5;
      }
    }

    //----------------------------------
    // 6- لبخند
    //----------------------------------

    for (final face in topFaces) {
      score += face.smilingProbability * 2;
    }

    //----------------------------------
    // 7- چهره بزرگتر
    //----------------------------------

    if (topFaces.isNotEmpty) {
      score += topFaces.first.faceArea / 100000;
    }

    return score;
  }

  void selectTimelinePhotos(List<MediaItem> items) {
    for (final item in items) {
      item.selected = true;

      final score = _smartScore(item);

      if (score < 0) {
        item.selected = false;
      }
    }
  }
}
