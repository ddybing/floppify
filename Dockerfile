# This Docker image will build and export the kernel binary for the given project.

FROM ghcr.io/uiaict/2024-ikt218-osdev/devcontainer:0bd4640

WORKDIR /build

USER root

ARG STUDENTFOLDER
ARG GRPNAME

ENV SRC_FOLDER=/src
ENV BUILD_FOLDER=/build

# Set environment variables
ENV CMAKELIST=${SRC_FOLDER}/CMakeLists.txt

ENV CC=/usr/local/bin/i686-elf-gcc
ENV CXX=/usr/local/bin/i686-elf-g++

# Set entrypoint
ENTRYPOINT ["sh", "-c", "cd ${BUILD_FOLDER} && cmake ${SRC_FOLDER} && cmake --build ${BUILD_FOLDER} --target uiaos-kernel && cmake --build ${BUILD_FOLDER} --target uiaos-create-image"]
