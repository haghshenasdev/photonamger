#include "../include/api.h"

#include "../include/engine.h"

static Engine engine;

bool Initialize()
{
    return engine.initialize();
}

void Dispose()
{
    engine.dispose();
}

int Version()
{
    return 1;
}

bool LoadImage(const char* filename)
{
    return engine.loadImage(filename);
}

int ImageWidth()
{
    return engine.imageWidth();
}

int ImageHeight()
{
    return engine.imageHeight();
}

bool Initialize(const char* modelPath)
{
    return engine.initialize(modelPath);
}