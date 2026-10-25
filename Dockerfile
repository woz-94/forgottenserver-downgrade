FROM ubuntu:22.04 AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl zip unzip tar build-essential cmake ninja-build pkg-config \
    ca-certificates && rm -rf /var/lib/apt/lists/*
# vcpkg
WORKDIR /opt
RUN git clone https://github.com/microsoft/vcpkg.git && cd vcpkg && ./bootstrap-vcpkg.sh
ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"
# Dependencies (manifest mode, cached until vcpkg.json changes)
WORKDIR /usr/src/forgottenserver-downgrade
COPY vcpkg.json ./
RUN /opt/vcpkg/vcpkg install --triplet x64-linux
# Source + single CMake configure/build with the vcpkg toolchain
COPY cmake /usr/src/forgottenserver-downgrade/cmake/
COPY src /usr/src/forgottenserver-downgrade/src/
COPY CMakeLists.txt /usr/src/forgottenserver-downgrade/
WORKDIR /usr/src/forgottenserver-downgrade
RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake \
    && cmake --build build

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/src/forgottenserver-downgrade/build/tfs /bin/tfs
# vcpkg shared libraries (libmariadb, openssl, fmt, ...) must survive into the runtime stage
COPY --from=build /opt/vcpkg/installed/x64-linux/lib/ /usr/local/lib/
RUN ldconfig
COPY data /srv/data/
COPY LICENSE README.md config.lua.dist schema.sql key.pem /srv/
EXPOSE 7171 7172
WORKDIR /srv
VOLUME /srv
ENTRYPOINT ["/bin/tfs"]
