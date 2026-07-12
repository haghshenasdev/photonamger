#include "../include/face_cluster.h"

#include <queue>

namespace fg
{

    ////////////////////////////////////////////////////////////

    FaceCluster::FaceCluster()
    {
    }

    ////////////////////////////////////////////////////////////

    FaceCluster::~FaceCluster()
    {
    }

    ////////////////////////////////////////////////////////////

    void FaceCluster::setOptions(
        const ClusterOptions& options)
    {
        _options = options;
    }

    ////////////////////////////////////////////////////////////

    const ClusterOptions& FaceCluster::options() const
    {
        return _options;
    }

    ////////////////////////////////////////////////////////////

    std::vector<PersonGroup> FaceCluster::cluster(
        const std::vector<ImageInfo>& images)
    {
        std::vector<PersonGroup> groups;

        if (images.empty())
            return groups;

        //----------------------------------------------------
        // مقداردهی اولیه
        //----------------------------------------------------

        std::vector<int> labels(
            images.size(),
            UNVISITED);

        std::vector<bool> visited(
            images.size(),
            false);

        int clusterId = 0;

        //----------------------------------------------------
        // پیمایش تصاویر
        //----------------------------------------------------

        for (size_t i = 0; i < images.size(); i++)
        {
            if (visited[i])
                continue;

            visited[i] = true;

            //------------------------------------------------
            // همسایه‌ها
            //------------------------------------------------

            auto neighbors =
                regionQuery(
                    static_cast<int>(i),
                    images);

            //------------------------------------------------
            // نویز
            //------------------------------------------------

            if (neighbors.size() <
                static_cast<size_t>(_options.minSamples))
            {
                labels[i] = NOISE;

                continue;
            }

            //------------------------------------------------
            // خوشه جدید
            //------------------------------------------------

            labels[i] = clusterId;

            expandCluster(
                static_cast<int>(i),
                clusterId,
                images,
                labels,
                visited);

            clusterId++;
        }

        //----------------------------------------------------
        // ساخت خروجی
        //----------------------------------------------------

        groups.resize(clusterId);

        for (int i = 0; i < clusterId; i++)
        {
            groups[i].id = i;
        }

        for (size_t i = 0; i < labels.size(); i++)
        {
            if (labels[i] >= 0)
            {
                groups[labels[i]]
                    .imageIndexes
                    .push_back(
                        static_cast<int>(i));
            }
        }

        return groups;
    }

}
////////////////////////////////////////////////////////////

void FaceCluster::expandCluster(
    int index,
    int clusterId,
    const std::vector<ImageInfo>& images,
    std::vector<int>& labels,
    std::vector<bool>& visited)
{
    //----------------------------------------------------
    // صف DBSCAN
    //----------------------------------------------------

    std::queue<int> queue;

    queue.push(index);

    while (!queue.empty())
    {
        const int current = queue.front();

        queue.pop();

        //--------------------------------------------
        // همسایه‌های current
        //--------------------------------------------

        auto neighbors =
            regionQuery(
                current,
                images);

        //--------------------------------------------
        // اگر نقطه مرزی باشد
        //--------------------------------------------

        if (neighbors.size() <
            static_cast<size_t>(_options.minSamples))
        {
            continue;
        }

        //--------------------------------------------
        // تمام همسایه‌ها
        //--------------------------------------------

        for (int neighbor : neighbors)
        {
            //----------------------------------------
            // اولین بازدید
            //----------------------------------------

            if (!visited[neighbor])
            {
                visited[neighbor] = true;

                queue.push(neighbor);
            }

            //----------------------------------------
            // قبلاً عضو هیچ خوشه‌ای نبوده
            //----------------------------------------

            if (labels[neighbor] == UNVISITED ||
                labels[neighbor] == NOISE)
            {
                labels[neighbor] = clusterId;
            }
        }
    }
}
////////////////////////////////////////////////////////////

std::vector<int> FaceCluster::regionQuery(
    int index,
    const std::vector<ImageInfo>& images)
{
    std::vector<int> neighbors;

    //----------------------------------------------------
    // تصویر مبنا
    //----------------------------------------------------

    if (images[index].faces.empty())
        return neighbors;

    const auto& embedding =
        images[index].faces[0].embedding;

    if (embedding.empty())
        return neighbors;

    //----------------------------------------------------
    // جستجوی همسایه‌ها
    //----------------------------------------------------

    for (size_t i = 0; i < images.size(); i++)
    {
        if (i == static_cast<size_t>(index))
            continue;

        if (images[i].faces.empty())
            continue;

        const auto& otherEmbedding =
            images[i].faces[0].embedding;

        if (otherEmbedding.empty())
            continue;

        const double d =
            distance(
                embedding,
                otherEmbedding);

        if (d <= _options.eps)
        {
            neighbors.push_back(
                static_cast<int>(i));
        }
    }

    return neighbors;
}

////////////////////////////////////////////////////////////

double FaceCluster::distance(
    const std::vector<float>& a,
    const std::vector<float>& b) const
{
    if (a.size() != b.size())
        return 999999.0;

    if (a.empty())
        return 999999.0;

    double sum = 0.0;

    const size_t n = a.size();

    for (size_t i = 0; i < n; i++)
    {
        const double diff =
            static_cast<double>(a[i]) -
            static_cast<double>(b[i]);

        sum += diff * diff;
    }

    return std::sqrt(sum);
}

}