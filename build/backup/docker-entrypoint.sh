#!/bin/sh

set -e -x

keybase_login () {
    keybase service &

    for retry in $(seq 5 0); do
        if keybase ping; then break; fi
        if [ "$retry" = 0 ]; then
            echo >&2 "keybase ping: Timed out"
            exit 2
        else
            sleep 1
        fi
    done

    if [ -z "$KEYBASE_USERNAME" ]; then
        KEYBASE_USERNAME="$(cat /run/secrets/XXX/keybase_username)"
    fi

    if [ -z "$KEYBASE_PAPERKEY" ]; then
        KEYBASE_PAPERKEY="$(cat /run/secrets/XXX/keybase_paperkey)"
    fi

    keybase oneshot
}

keybase_login
exec sleep 86400
