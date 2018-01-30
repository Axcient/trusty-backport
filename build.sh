#!/bin/sh
docker build \
    --build-arg name="Jared Johnson" \
    --build-arg email="jjohnson@efolder.net" \
    --build-arg version="efs1404+0" \
    --build-arg distribution="rb-trusty-alpha" \
    -t \
    build-trusty \
    .

docker run --rm -it -v "${PWD}/output:/out" build-trusty
