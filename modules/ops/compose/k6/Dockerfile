# xk6-sql(PostgreSQL 드라이버) 포함 k6 커스텀 빌드.
# vanilla grafana/k6 이미지엔 확장이 없어 xk6 로 직접 빌드해야 한다.
FROM grafana/xk6:latest AS build
RUN xk6 build \
    --with github.com/grafana/xk6-sql@v1.0.5 \
    --with github.com/grafana/xk6-sql-driver-postgres@latest \
    --output /k6

FROM alpine:3.20
RUN apk add --no-cache ca-certificates && adduser -D -u 12345 k6
COPY --from=build /k6 /usr/bin/k6
USER 12345
WORKDIR /scripts
ENTRYPOINT ["k6"]
