# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.6
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install ImageMagick and Tesseract OCR
USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    imagemagick \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*
USER vscode
