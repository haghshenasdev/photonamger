#pragma once

#include <string>
#include <vector>

#include <opencv2/core.hpp>
#include <opencv2/objdetect/face.hpp>

#include "image.h"
#include "types.h"

namespace fg
{

    class FaceDetector
    {
    public:

        FaceDetector();

        ~FaceDetector();

        //-------------------------------------------------
        // بارگذاری مدل YuNet
        //-------------------------------------------------

        bool loadModel(
            const std::string& modelPath,
            const FaceDetectorOptions& options = FaceDetectorOptions()
        );

        //-------------------------------------------------
        // آیا مدل بارگذاری شده؟
        //-------------------------------------------------

        bool isLoaded() const;

        //-------------------------------------------------
        // آزادسازی حافظه
        //-------------------------------------------------

        void clear();

        //-------------------------------------------------
        // تشخیص چهره
        //-------------------------------------------------

        std::vector<Face> detect(
            const Image& image
        );

    private:

        FaceDetectorOptions _options;

        cv::Ptr<cv::FaceDetectorYN> _detector;

        bool _loaded = false;
    };

}