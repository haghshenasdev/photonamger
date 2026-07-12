#include "../include/face_recognizer.h"

#include <cmath>

namespace fg
{

    ////////////////////////////////////////////////////////////

    FaceRecognizer::FaceRecognizer()
    {
    }

    ////////////////////////////////////////////////////////////

    FaceRecognizer::~FaceRecognizer()
    {
        clear();
    }

    ////////////////////////////////////////////////////////////

    bool FaceRecognizer::loadModel(
        const std::string& modelPath,
        const RecognizerOptions& options)
    {
        clear();

        _options = options;

        try
        {
            _recognizer = cv::FaceRecognizerSF::create(
                modelPath,
                ""
            );

            _loaded = (_recognizer != nullptr);

            return _loaded;
        }
        catch (...)
        {
            _loaded = false;

            return false;
        }
    }

    ////////////////////////////////////////////////////////////

    bool FaceRecognizer::isLoaded() const
    {
        return _loaded;
    }

    ////////////////////////////////////////////////////////////

    void FaceRecognizer::clear()
    {
        _recognizer.release();

        _loaded = false;
    }
    ////////////////////////////////////////////////////////////

    std::vector<float> FaceRecognizer::extract(
        const Image& image,
        const Face& face)
    {
        std::vector<float> embedding;

        if (!_loaded)
            return embedding;

        if (image.empty())
            return embedding;

        if (face.landmarks.size() != 5)
            return embedding;

        try
        {
            //----------------------------------------------------
            // ساخت ماتریس مشخصات چهره
            //----------------------------------------------------

            cv::Mat faceBox(1, 15, CV_32FC1);

            float* p = faceBox.ptr<float>();

            p[0] = face.rect.left;
            p[1] = face.rect.top;
            p[2] = face.rect.width;
            p[3] = face.rect.height;

            for (int i = 0; i < 5; i++)
            {
                p[4 + i * 2] = face.landmarks[i].x;
                p[5 + i * 2] = face.landmarks[i].y;
            }

            p[14] = face.score;

            //----------------------------------------------------
            // Align
            //----------------------------------------------------

            cv::Mat alignedFace;

            _recognizer->alignCrop(
                image.mat(),
                faceBox,
                alignedFace);

            if (alignedFace.empty())
                return embedding;

            //----------------------------------------------------
            // استخراج Feature
            //----------------------------------------------------

            cv::Mat feature;

            _recognizer->feature(
                alignedFace,
                feature);

            if (feature.empty())
                return embedding;

            //----------------------------------------------------
            // تبدیل به vector<float>
            //----------------------------------------------------

            embedding.resize(feature.cols);

            const float* data = feature.ptr<float>();

            for (int i = 0; i < feature.cols; i++)
            {
                embedding[i] = data[i];
            }

            //----------------------------------------------------
            // نرمال سازی اختیاری
            //----------------------------------------------------

            if (_options.normalizeEmbedding)
            {
                double sum = 0.0;

                for (float v : embedding)
                    sum += v * v;

                double norm = std::sqrt(sum);

                if (norm > 0.0)
                {
                    for (float& v : embedding)
                        v /= static_cast<float>(norm);
                }
            }

            return embedding;
        }
        catch (...)
        {
            embedding.clear();

            return embedding;
        }
    }
    ////////////////////////////////////////////////////////////

    double FaceRecognizer::cosineSimilarity(
        const std::vector<float>& emb1,
        const std::vector<float>& emb2) const
    {
        if (emb1.empty() || emb2.empty())
            return 0.0;

        if (emb1.size() != emb2.size())
            return 0.0;

        double dot = 0.0;
        double norm1 = 0.0;
        double norm2 = 0.0;

        const size_t n = emb1.size();

        for (size_t i = 0; i < n; i++)
        {
            dot += static_cast<double>(emb1[i]) * emb2[i];

            norm1 += static_cast<double>(emb1[i]) * emb1[i];

            norm2 += static_cast<double>(emb2[i]) * emb2[i];
        }

        if (norm1 == 0.0 || norm2 == 0.0)
            return 0.0;

        return dot / (std::sqrt(norm1) * std::sqrt(norm2));
    }

    ////////////////////////////////////////////////////////////

    double FaceRecognizer::l2Distance(
        const std::vector<float>& emb1,
        const std::vector<float>& emb2) const
    {
        if (emb1.empty() || emb2.empty())
            return 9999.0;

        if (emb1.size() != emb2.size())
            return 9999.0;

        double sum = 0.0;

        const size_t n = emb1.size();

        for (size_t i = 0; i < n; i++)
        {
            const double d =
                static_cast<double>(emb1[i]) -
                static_cast<double>(emb2[i]);

            sum += d * d;
        }

        return std::sqrt(sum);
    }

}