# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: Build the React/Vite application
# ============================================================

FROM registry.access.redhat.com/ubi9/nodejs-20 AS build

WORKDIR /opt/app-root/src

# Install pinned dependencies first for better build caching
COPY package.json package-lock.json ./

RUN npm ci --no-audit --no-fund

# Copy the application source
COPY . .

# Generate the production Vite output
RUN npm run build

# Fail the image build if the expected Vite output is missing
RUN test -f /opt/app-root/src/dist/index.html && \
    test -d /opt/app-root/src/dist/assets

# ============================================================
# Stage 2: Serve the compiled application with rootless NGINX
# ============================================================

FROM nginxinc/nginx-unprivileged:alpine-slim

USER root

# Remove default web content and default server configuration
RUN rm -rf /usr/share/nginx/html/* && \
    rm -f /etc/nginx/conf.d/default.conf

# Copy only the compiled Vite production output
COPY --from=build /opt/app-root/src/dist/ /usr/share/nginx/html/

# Your nginx.conf is a complete configuration containing
# worker_processes, events, http, and server blocks.
COPY nginx.conf /etc/nginx/nginx.conf

# Allow the arbitrary OpenShift UID, which runs with GID 0,
# to read/write only the required paths.
RUN chgrp -R 0 \
      /usr/share/nginx/html \
      /etc/nginx \
      /var/cache/nginx \
      /var/log/nginx && \
    chmod -R g=u \
      /usr/share/nginx/html \
      /etc/nginx \
      /var/cache/nginx \
      /var/log/nginx

EXPOSE 8080

# Do not specify USER 101.
# OpenShift restricted-v2 assigns an arbitrary non-root UID.

CMD ["nginx", "-g", "daemon off;"]