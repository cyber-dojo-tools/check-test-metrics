FROM cyberdojo/ruby-base:latest
LABEL maintainer=jon@jaggersoft.com

COPY --chown=nobody:nogroup . /app
ARG COMMIT_SHA
ENV SHA="${COMMIT_SHA}"
ENTRYPOINT [ "ruby", "/app/check_test_metrics.rb" ] 
