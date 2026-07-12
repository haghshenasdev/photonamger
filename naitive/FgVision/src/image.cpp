#include "../include/image.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace fg
{

    Image::Image()
    {
    }

    Image::Image(const std::string& fileName)
    {
        load(fileName);
    }

    Image::~Image()
    {
        clear();
    }

    /////////////////////////////////////////////////////////

    bool Image::load(const std::string& fileName)
    {
        clear();

        _fileName = fileName;

        _mat = cv::imread(fileName, cv::IMREAD_COLOR);

        return !_mat.empty();
    }

    /////////////////////////////////////////////////////////

    void Image::clear()
    {
        _mat.release();

        _fileName.clear();
    }

    /////////////////////////////////////////////////////////

    bool Image::save(const std::string& fileName) const
    {
        if (_mat.empty())
            return false;

        return cv::imwrite(fileName, _mat);
    }

    /////////////////////////////////////////////////////////

    bool Image::empty() const
    {
        return _mat.empty();
    }

    bool Image::isLoaded() const
    {
        return !_mat.empty();
    }

    /////////////////////////////////////////////////////////

    int Image::width() const
    {
        if (_mat.empty())
            return 0;

        return _mat.cols;
    }

    /////////////////////////////////////////////////////////

    int Image::height() const
    {
        if (_mat.empty())
            return 0;

        return _mat.rows;
    }

    /////////////////////////////////////////////////////////

    int Image::channels() const
    {
        if (_mat.empty())
            return 0;

        return _mat.channels();
    }

    /////////////////////////////////////////////////////////

    int Image::type() const
    {
        if (_mat.empty())
            return -1;

        return _mat.type();
    }

    /////////////////////////////////////////////////////////

    const std::string& Image::fileName() const
    {
        return _fileName;
    }

    /////////////////////////////////////////////////////////

    cv::Mat& Image::mat()
    {
        return _mat;
    }

    const cv::Mat& Image::mat() const
    {
        return _mat;
    }

    /////////////////////////////////////////////////////////

    Image Image::clone() const
    {
        Image result;

        result._fileName = _fileName;

        if (!_mat.empty())
        {
            result._mat = _mat.clone();
        }

        return result;
    }

    /////////////////////////////////////////////////////////

    Image Image::gray() const
    {
        Image result;

        result._fileName = _fileName;

        if (_mat.empty())
            return result;

        if (_mat.channels() == 1)
        {
            result._mat = _mat.clone();
        }
        else
        {
            cv::cvtColor(
                _mat,
                result._mat,
                cv::COLOR_BGR2GRAY
            );
        }

        return result;
    }

    /////////////////////////////////////////////////////////

    Image Image::resize(
        int width,
        int height
    ) const
    {
        Image result;

        result._fileName = _fileName;

        if (_mat.empty())
            return result;

        cv::resize(
            _mat,
            result._mat,
            cv::Size(width, height),
            0,
            0,
            cv::INTER_AREA
        );

        return result;
    }

    /////////////////////////////////////////////////////////

    Image Image::crop(
        int x,
        int y,
        int width,
        int height
    ) const
    {
        Image result;

        result._fileName = _fileName;

        if (_mat.empty())
            return result;

        cv::Rect roi(
            x,
            y,
            width,
            height
        );

        roi &= cv::Rect(
            0,
            0,
            _mat.cols,
            _mat.rows
        );

        if (roi.width <= 0 || roi.height <= 0)
            return result;

        result._mat = _mat(roi).clone();

        return result;
    }

}