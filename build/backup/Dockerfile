FROM golang as builder

# Use Keybase (https://keybase.io) to dump secrets, pending a smarter way
# Use a separate step to get the sources as they are H E A V Y
RUN go get github.com/keybase/client/go/keybase
RUN go get github.com/keybase/kbfs/kbfsgit/git-remote-keybase
RUN go install -v --ldflags '-extldflags "-static"' -tags production github.com/keybase/client/go/keybase
RUN go install -v --ldflags '-extldflags "-static"' -tags production github.com/keybase/kbfs/kbfsgit/git-remote-keybase

FROM ubuntu:latest

RUN set -e -x; export DEBIAN_FRONTEND=noninteractive; apt -qy update; apt -qy install git

COPY --from=builder /go/bin/keybase /usr/local/bin/keybase
COPY --from=builder /go/bin/git-remote-keybase /usr/local/bin/git-remote-keybase
RUN mkdir /var/www && chown www-data:www-data /var/www
USER www-data

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

