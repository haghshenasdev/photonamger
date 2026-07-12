#pragma once

#include <string>

#include <opencv2/core.hpp>

namespace fg
{

    class Image
    {
    public:

        Image();

        explicit Image(const std::string& fileName);

        ~Image();

        //-------------------------------------------------
        // بارگذاری
        //-------------------------------------------------

        bool load(const std::string& fileName);

        void clear();

        bool save(const std::string& fileName) const;

        //-------------------------------------------------
        // وضعیت
        //-------------------------------------------------

        bool empty() const;

        bool isLoaded() const;

        //-------------------------------------------------
        // مشخصات
        //-------------------------------------------------

        int width() const;

        int height() const;

        int channels() const;

        int type() const;

        //-------------------------------------------------
        // مسیر فایل
        //-------------------------------------------------

        const std::string& fileName() const;

        //-------------------------------------------------
        // دسترسی به Mat
        //-------------------------------------------------

        cv::Mat& mat();

        const cv::Mat& mat() const;

        //-------------------------------------------------
        // تبدیل‌ها
        //-------------------------------------------------

        Image clone() const;

        Image gray() const;

        Image resize(
            int width,
            int height
        ) const;

        Image crop(
            int x,
            int y,
            int width,
            int height
        ) const;

    private:

        std::string _fileName;

        cv::Mat _mat;
    };

}