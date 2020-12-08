#!/bin/bash -Ee

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#- - - - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  echo cyberdojo/check-test-metrics
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
build_image()
{
  docker build \
    --build-arg COMMIT_SHA="$(git_commit_sha)" \
    --tag "$(image_name)" \
    "${ROOT_DIR}/source"
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
git_commit_sha()
{
  echo $(cd "${ROOT_DIR}" && git rev-parse HEAD)
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  docker run --entrypoint="" --rm "$(image_name)" sh -c 'echo ${SHA}'
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
assert_equal()
{
  local -r expected="${1}"
  local -r actual="${2}"
  echo "expected: '${expected}'"
  echo "  actual: '${actual}'"
  if [ "${expected}" != "${actual}" ]; then
    echo "FAILED: inside image $(image_name):latest"
    exit 42
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
tag_image()
{
  docker tag "$(image_name):latest" "$(image_name):$(image_tag)"
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
image_tag()
{
  local -r sha="$(image_sha)"
  echo "${sha:0:7}"
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_publish_images()
{
  if ! on_ci; then
    echo 'not on CI so not publishing tagged images'
    return
  fi
  echo 'on CI so publishing tagged images'
  docker push "$(image_name):latest"
  docker push "$(image_name):$(image_tag)"
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CIRCLECI}" ]
}

#- - - - - - - - - - - - - - - - - - - - - - - - -
build_image
assert_equal "SHA=$(git_commit_sha)" "SHA=$(image_sha)"
tag_image
on_ci_publish_images
