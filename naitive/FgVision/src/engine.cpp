#include "../include/engine.h"

bool Engine::initialize()
{
    return _faceDetector.initialize();
}

void Engine::dispose()
{
    _faceDetector.dispose();
}

bool Engine::loadImage(const char* filename)
{
    return _image.load(filename);
}

int Engine::imageWidth() const
{
    return _image.width();
}

int Engine::imageHeight() const
{
    return _image.height();
}

std::vector<FGFace> Engine::detectFaces()
{
    return _faceDetector.detect(_image);
}

bool Engine::initialize(const std::string& modelPath)
{
    return _faceDetector.initialize(modelPath);
}