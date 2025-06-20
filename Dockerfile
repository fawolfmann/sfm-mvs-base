ARG UBUNTU_VERSION=22.04
ARG NVIDIA_CUDA_VERSION=12.3.1
# check you arch https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/#gpu-feature-list

FROM --platform=linux/amd64 nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
ENV CUDA_ARCHITECTURES="75;80;86"
ENV QT_XCB_GL_INTEGRATION=xcb_egl
ENV DEBIAN_FRONTEND=noninteractive

# Prepare and empty machine for building.
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
    git \
    build-essential \
    cmake \
    ninja-build \
    wget \
    unzip \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libceres-dev \
    libflann-dev \
    libfreeimage-dev \
    libmetis-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libsqlite3-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libcgal-qt5-dev \
    libgl1-mesa-dri \
    libunwind-dev \
    xvfb \
    clang-format-14 \
    python3 \
    python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install newer version of CMake
RUN apt-get install -y wget && \
    wget https://github.com/Kitware/CMake/releases/download/v3.30.1/cmake-3.30.1-linux-x86_64.sh && \
    chmod +x cmake-3.30.1-linux-x86_64.sh && \
    ./cmake-3.30.1-linux-x86_64.sh --skip-license --prefix=/usr/local

# Set up compiler environment
RUN apt-get update && \
    apt-get install -y \
    clang-15 \
    libomp-15-dev \
    gcc-10 \
    g++-10 \
    nvidia-cuda-toolkit \
    nvidia-cuda-toolkit-gcc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV CC=/usr/bin/gcc-10
ENV CXX=/usr/bin/g++-10
ENV CUDAHOSTCXX=/usr/bin/g++-10

# Build and install COLMAP
RUN git clone https://github.com/colmap/colmap.git

RUN cd colmap && \
    mkdir build && \
    cd build && \
    cmake .. \
        -GNinja \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
        -DCMAKE_INSTALL_PREFIX=/colmap_installed && \
    ninja install
RUN cp -r /colmap_installed/* /usr/local/

# Build and install GLOMAP
RUN git clone https://github.com/colmap/glomap.git
RUN cd glomap && \
    mkdir build && \
    cd build && \
    cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/glomap_installed \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
        -DSuiteSparse_CHOLMOD_LIBRARY="/usr/lib/x86_64-linux-gnu/libcholmod.so" \
        -DSuiteSparse_CHOLMOD_INCLUDE_DIR="/usr/include/suitesparse" \
        -DTESTS_ENABLED=OFF \
        -DASAN_ENABLED=false && \
    ninja install
RUN cp -r /glomap_installed/* /usr/local/

# Install python packages
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

COPY pyproject.toml uv.lock .python-version ./

# install uv dependencies
RUN uv sync --locked
