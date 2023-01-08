[![Github Action (main)](https://github.com/cyber-dojo-tools/check-test-metrics/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo-tools/check-test-metrics/actions)


# check-test-metrics

Combines test-run data from three sources whose filenames are specified on the command-line:
- `ARGV[0]` The minitest stdout. Provides failure-count, error-count, skip-count
- `ARGV[1]` The custom SimpleCov json report. Provides branch coverage stats.  
          Eg. https://github.com/cyber-dojo/runner/blob/master/test/lib/simplecov-json.rb
- `ARGV[2]` The max-metrics json file to check against ARGV[1] which determines the exit code. 
          Eg. https://github.com/cyber-dojo/runner/blob/master/test/server/max_metrics.json. 

Also relies on two environment variables (keys into the json from ARGV[1]) 
- `ENV['CODE_DIR']` is coverage for the code
- `ENV['TEST_DIR']` is coverage for the tests

Typical use is:
```bash
docker run \
    --rm \
    --env CODE_DIR="${CODE_DIR}" \
    --env TEST_DIR="${TEST_DIR}" \
    --volume ${HOST_REPORTS_DIR}/${TEST_LOG}:${CONTAINER_TMP_DIR}/${TEST_LOG}:ro \
    --volume ${HOST_REPORTS_DIR}/coverage.json:${CONTAINER_TMP_DIR}/coverage.json:ro \
    --volume ${HOST_TEST_DIR}/max_metrics.json:${CONTAINER_TMP_DIR}/max_metrics.json:ro \
    cyberdojo/check-test-metrics:latest \
      "${CONTAINER_TMP_DIR}/${TEST_LOG}" \
      "${CONTAINER_TMP_DIR}/coverage.json" \
      "${CONTAINER_TMP_DIR}/max_metrics.json" \
    | tee -a "${HOST_REPORTS_DIR}/${TEST_LOG}"
```

Eg https://github.com/cyber-dojo/runner/blob/master/sh/test_in_containers.sh#L102