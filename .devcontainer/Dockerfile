# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.6
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install ZBar
USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    zbar-tools \
    libzbar0 \
    libzbar-dev \
    pkg-config \
    && ln -s /usr/lib/*/libzbar.so /usr/lib/ \
    && rm -rf /var/lib/apt/lists/*
USER vscode