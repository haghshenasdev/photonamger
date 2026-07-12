#pragma once

#include <vector>

#include "types.h"

namespace fg
{

    class FaceCluster
    {
    public:

        FaceCluster();

        ~FaceCluster();

        //-------------------------------------------------
        // تنظیمات
        //-------------------------------------------------

        void setOptions(
            const ClusterOptions& options);

        const ClusterOptions& options() const;

        //-------------------------------------------------
        // خوشه بندی
        //-------------------------------------------------

        std::vector<PersonGroup> cluster(
            const std::vector<ImageInfo>& images);

    private:

        //-------------------------------------------------
        // DBSCAN
        //-------------------------------------------------

        void expandCluster(
            int index,
            int clusterId,
            const std::vector<ImageInfo>& images,
            std::vector<int>& labels,
            std::vector<bool>& visited);

        //-------------------------------------------------

        std::vector<int> regionQuery(
            int index,
            const std::vector<ImageInfo>& images);

        //-------------------------------------------------

        double distance(
            const std::vector<float>& a,
            const std::vector<float>& b) const;

        //-------------------------------------------------

        static constexpr int NOISE = -1;

        static constexpr int UNVISITED = -2;

    private:

        ClusterOptions _options;
    };

}