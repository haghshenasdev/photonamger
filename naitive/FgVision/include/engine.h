#pragma once

#include "image.h"
#include "face_detector.h"

class Engine
{
public:

    bool initialize();

    void dispose();

    bool loadImage(const char* filename);

    int imageWidth() const;

    int imageHeight() const;

    std::vector<FGFace> detectFaces();

    bool initialize(const std::string& modelPath);

private:

    Image _image;

    FaceDetector _faceDetector;

};