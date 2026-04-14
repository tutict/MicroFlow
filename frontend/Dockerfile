FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /workspace

COPY pubspec.yaml pubspec.lock ./

RUN flutter config --enable-web && flutter pub get

COPY . .

RUN flutter build web --release

FROM nginx:1.27-alpine

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ > /dev/null || exit 1
