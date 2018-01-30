# Backport Xenial packages to Trusty

Use Docker to help build updated packages against Trusty

# Build instructions

## General

```sh
docker build -t build-trusty .
docker run -it -v "${PWD}/output:/out" build-trusty
```

All packages built in the docker container will appear in the `output` directory.

