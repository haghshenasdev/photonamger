#pragma once

#include <string>
#include <vector>

#include <opencv2/core.hpp>
#include <opencv2/objdetect/face.hpp>

#include "image.h"
#include "types.h"

namespace fg
{

    class FaceRecognizer
    {
    public:

        FaceRecognizer();

        ~FaceRecognizer();

        //-------------------------------------------------
        // بارگذاری مدل SFace
        //-------------------------------------------------

        bool loadModel(
            const std::string& modelPath,
            const RecognizerOptions& options = RecognizerOptions()
        );

        //-------------------------------------------------
        // آیا مدل بارگذاری شده؟
        //-------------------------------------------------

        bool isLoaded() const;

        //-------------------------------------------------
        // آزادسازی
        //-------------------------------------------------

        void clear();

        //-------------------------------------------------
        // استخراج Embedding
        //-------------------------------------------------

        std::vector<float> extract(
            const Image& image,
            const Face& face
        );

        //-------------------------------------------------
        // مقایسه دو Embedding
        //-------------------------------------------------

        double cosineSimilarity(
            const std::vector<float>& emb1,
            const std::vector<float>& emb2
        ) const;

        //-------------------------------------------------
        // فاصله L2
        //-------------------------------------------------

        double l2Distance(
            const std::vector<float>& emb1,
            const std::vector<float>& emb2
        ) const;

    private:

        RecognizerOptions _options;

        cv::Ptr<cv::FaceRecognizerSF> _recognizer;

        bool _loaded = false;
    };

}