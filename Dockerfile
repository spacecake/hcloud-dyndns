FROM alpine:3.23

RUN apk add --no-cache curl jq ca-certificates && update-ca-certificates

# Create non-root user
RUN addgroup -S app && adduser -S -G app app

COPY hcloud-dyndns.sh /usr/local/bin/hcloud-dyndns.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/hcloud-dyndns.sh /entrypoint.sh

USER app

ENTRYPOINT ["/entrypoint.sh"]
