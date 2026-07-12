#pragma once

#ifdef _WIN32
#define FGVISION_API __declspec(dllexport)
#else
#define FGVISION_API
#endif

extern "C"
{

	//--------------------------------------------------
	// Engine
	//--------------------------------------------------

	FGVISION_API bool Initialize();

	FGVISION_API void Dispose();

	FGVISION_API int Version();

	FGVISION_API bool LoadImage(const char* filename);

	FGVISION_API int ImageWidth();

	FGVISION_API int ImageHeight();

	FGVISION_API bool Initialize(const char* modelPath);

}