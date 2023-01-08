[![Github Action (main)](https://github.com/cyber-dojo-tools/check-test-metrics/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo-tools/check-test-metrics/actions)


# check-test-metrics

Combines test-run data from three sources whose filenames are specified on the command-line:
- ARGV[0] The minitest stdout
          Provides failure-count, error-count, skip-count
- ARGV[1] The custom SimpleCov json report.
          Provides branch coverage stats.
          See https://github.com/cyber-dojo/differ/blob/master/test/lib/simplecov-json.rb
- ARGV[2] The max-metrics json file
          The values in 1) and 2) must not exceed these.

Also relies on two environment variables (keys into ARGV[1]) 
- ENV['CODE_DIR'] is coverage for the code
- ENV['TEST_DIR'] is coverage for the tests