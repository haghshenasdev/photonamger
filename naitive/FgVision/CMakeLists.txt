cmake_minimum_required(VERSION 3.15)

project(FgVision)

set(CMAKE_CXX_STANDARD 17)

# مسیر نصب OpenCV
set(OpenCV_DIR "C:/opencv/build")

find_package(OpenCV REQUIRED)

include_directories(

    include

    ${OpenCV_INCLUDE_DIRS}

)

add_library(FgVision SHARED

    src/api.cpp
    src/engine.cpp
    src/image.cpp
    src/face_detector.cpp

)

target_link_libraries(

    FgVision

    ${OpenCV_LIBS}

)