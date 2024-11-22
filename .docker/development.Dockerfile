FROM pandoc/core AS base

RUN apk add --no-cache --no-interactive \
    git
