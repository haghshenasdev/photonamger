#include "../include/face_detector.h"

#include <opencv2/imgproc.hpp>

namespace fg
{

    FaceDetector::FaceDetector()
    {
    }

    FaceDetector::~FaceDetector()
    {
        clear();
    }

    /////////////////////////////////////////////////////////////

    bool FaceDetector::loadModel(
        const std::string& modelPath,
        const FaceDetectorOptions& options)
    {
        clear();

        _options = options;

        try
        {
            _detector = cv::FaceDetectorYN::create(
                modelPath,
                "",
                cv::Size(
                    options.inputWidth,
                    options.inputHeight),
                options.scoreThreshold,
                options.nmsThreshold,
                options.topK);

            _loaded = (_detector != nullptr);

            return _loaded;
        }
        catch (...)
        {
            _loaded = false;
            return false;
        }
    }

    /////////////////////////////////////////////////////////////

    bool FaceDetector::isLoaded() const
    {
        return _loaded;
    }

    /////////////////////////////////////////////////////////////

    void FaceDetector::clear()
    {
        _detector.release();

        _loaded = false;
    }

    /////////////////////////////////////////////////////////////

    std::vector<Face> FaceDetector::detect(
        const Image& image)
    {
        std::vector<Face> result;

        if (!_loaded)
            return result;

        if (image.empty())
            return result;

        //-------------------------------------------------
        // YuNet باید اندازه تصویر را بداند
        //-------------------------------------------------

        _detector->setInputSize(
            cv::Size(
                image.width(),
                image.height()));

        cv::Mat detections;

        _detector->detect(
            image.mat(),
            detections);

        if (detections.empty())
            return result;

        //-------------------------------------------------
        // تبدیل خروجی OpenCV به ساختار خودمان
        //-------------------------------------------------

        for (int i = 0; i < detections.rows; i++)
        {
            Face face;

            const float* row =
                detections.ptr<float>(i);

            //-----------------------------------------
            // Bounding Box
            //-----------------------------------------

            face.rect.left = row[0];
            face.rect.top = row[1];
            face.rect.width = row[2];
            face.rect.height = row[3];

            //-----------------------------------------
            // Confidence
            //-----------------------------------------

            face.score = row[14];

            //-----------------------------------------
            // پنج نقطه کلیدی
            //-----------------------------------------

            face.landmarks.reserve(5);

            for (int p = 0; p < 5; p++)
            {
                Point pt;

                pt.x = row[4 + p * 2];
                pt.y = row[5 + p * 2];

                face.landmarks.push_back(pt);
            }

            result.push_back(std::move(face));
        }

        return result;
    }

}