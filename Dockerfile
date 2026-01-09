FROM alpine:3.20

RUN apk add --no-cache aws-cli curl ca-certificates && update-ca-certificates

WORKDIR /app
COPY heartbeat.sh /app/heartbeat.sh
RUN chmod +x /app/heartbeat.sh

ENTRYPOINT ["/app/heartbeat.sh"]
