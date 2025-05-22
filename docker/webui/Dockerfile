# syntax=docker/dockerfile:1.4

FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get install -y \
            git \
            python3.11-full \
            python3.11-dev \
            gosu \
            locales \
            libgoogle-perftools-dev \
            libgl1 \
            libglib2.0-0 \
            bc \
            build-essential \
            inetutils-ping \
            ffmpeg \
            wget
