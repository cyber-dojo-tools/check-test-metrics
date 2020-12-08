FROM cyberdojo/ruby-base:latest
LABEL maintainer=jon@jaggersoft.com

COPY --chown=nobody:nogroup . /app
ARG COMMIT_SHA
ENV SHA="${COMMIT_SHA}"
