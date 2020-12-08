
# Combines test-run data from three sources whose filenames are specified on the command-line
#   ARGV[0] The minitest stdout
#           Provides failure-count, error-count, skip-count
#   ARGV[1] The custom SimpleCov json report.
#           Provides branch coverage stats.
#           See https://github.com/cyber-dojo/differ/blob/master/test/lib/simplecov-json.rb
#   ARGV[2] The max-metrics json file
#           The values in 1) and 2) must not exceed these.
#
# Also relies on two coverage tab values (keys into ARGV[1]) being set in two env-vars
#   o) ENV['COVERAGE_CODE_TAB_NAME'] is coverage for the code
#   o) ENV['COVERAGE_TEST_TAB_NAME'] is coverage for the tests

require 'json'

def test_log_filename
  ARGV[0] # eg /test/server/reports/test.log
end

def coverage_json_filename
  ARGV[1] # eg /test/server/reports/coverage.json
end

def max_metrics_json_filename
  ARGV[2] # eg /test/server/reports/max_metrics.json
end

def coverage_code_tab_name
  ENV['COVERAGE_CODE_TAB_NAME']
end

def coverage_test_tab_name
  ENV['COVERAGE_TEST_TAB_NAME']
end

# - - - - - - - - - - - - - - - - - - - - - - -
def show_args
  p "ARGV[0] == #{ARGV[0]} (eg test.run.log)"
  p "ARGV[1] == #{ARGV[1]} (eg coverage.json)"
  p "ARGV[2] == #{ARGV[2]} (eg max_metrics.json)"
  p "ENV['COVERAGE_CODE_TAB_NAME'] == #{coverage_code_tab_name}"
  p "ENV['COVERAGE_TEST_TAB_NAME'] == #{coverage_test_tab_name}"
end

# - - - - - - - - - - - - - - - - - - - - - - -
def test_log
  $test_log ||= cleaned(IO.read(test_log_filename))
end

# - - - - - - - - - - - - - - - - - - - - - - -
def coverage_json
  $coverage_json ||= JSON.parse(IO.read(coverage_json_filename))
end

# - - - - - - - - - - - - - - - - - - - - - - -
def max_metrics_json
  $max_metrics_json ||= JSON.parse(IO.read(max_metrics_json_filename))
end

# - - - - - - - - - - - - - - - - - - - - - - -
def fatal_error(message)
  puts message
  exit(42)
end

# - - - - - - - - - - - - - - - - - - - - - - -
def version
  $version ||= begin
    %w( 0.19.1 ).each do |n|
      if test_log.include?("SimpleCov version #{n}")
        return n
      end
    end
    fatal_error('Unknown simplecov version!')
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
def cleaned(s)
  # guard against invalid byte sequence
  s = s.encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
  s = s.encode('UTF-8', 'UTF-16')
end

# - - - - - - - - - - - - - - - - - - - - - - -
def number
  '[\.|\d]+'
end

# - - - - - - - - - - - - - - - - - - - - - - -
def f2(s)
  result = ("%.2f" % s).to_s
  result += '0' if result.end_with?('.0')
  result
end

# - - - - - - - - - - - - - - - - - - - - - - -
def coloured(tf)
  red = 31
  green = 32
  colourize(tf ? green : red, tf)
end

# - - - - - - - - - - - - - - - - - - - - - - -
def colourize(code, word)
  "\e[#{code}m #{word} \e[0m"
end

# - - - - - - - - - - - - - - - - - - - - - - -
def get_coverage_stats(name)
  case version
    when '0.19.1' then coverage_json['groups'][name]
    else           fatal_error("Unknown simplecov version #{version}")
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
def get_test_log_stats
  stats = {}

  warning_regex = /: warning:/m
  stats[:warning_count] = test_log.scan(warning_regex).size

  finished_pattern = "Finished in (#{number})s, (#{number}) runs/s"
  m = test_log.match(Regexp.new(finished_pattern))
  stats[:time]               = f2(m[1])
  stats[:tests_per_sec]      = m[2].to_i

  summary_pattern =
    %w(runs assertions failures errors skips)
    .map{ |s| "(#{number}) #{s}" }
    .join(', ')
  m = test_log.match(Regexp.new(summary_pattern))
  stats[:failure_count]   = m[3].to_i
  stats[:error_count]     = m[4].to_i
  stats[:skip_count]      = m[5].to_i

  stats
end

# - - - - - - - - - - - - - - - - - - - - - - -
log_stats = get_test_log_stats

failure_count = log_stats[:failure_count]
error_count   = log_stats[:error_count]
warning_count = log_stats[:warning_count]
skip_count    = log_stats[:skip_count]
test_duration = log_stats[:time].to_f

MAX = max_metrics_json
unless MAX.keys.include?('code')
  p "max_metrics.json does not have key == 'code'"
end
unless MAX.keys.include?('test')
  p "max_metrics.json does not have key == 'test'"
end

table = [
  [ 'test:failures',    failure_count,  '<=',  MAX["failures"  ] ],
  [ 'test:errors',      error_count,    '<=',  MAX["errors"    ] ],
  [ 'test:warnings',    warning_count,  '<=',  MAX["warnings"  ] ],
  [ 'test:skips',       skip_count,     '<=',  MAX["skips"     ] ],
  [ 'test:duration(s)', test_duration,  '<=',  MAX["duration"  ] ],
]

test_stats = get_coverage_stats(coverage_test_tab_name)
code_stats = get_coverage_stats(coverage_code_tab_name)

table += [
  [ 'code:lines:total',     code_stats['lines'   ]['total' ], '<=', MAX["code"]["lines"   ]["total" ] ],
  [ 'code:lines:missed',    code_stats['lines'   ]['missed'], '<=', MAX["code"]["lines"   ]["missed"] ],
  [ 'code:branches:total',  code_stats['branches']['total' ], '<=', MAX["code"]["branches"]["total" ] ],
  [ 'code:branches:missed', code_stats['branches']['missed'], '<=', MAX["code"]["branches"]["missed"] ],

  [ 'test:lines:total',     test_stats['lines'   ]['total' ], '<=', MAX["test"]["lines"   ]["total"  ] ],
  [ 'test:lines:missed',    test_stats['lines'   ]['missed'], '<=', MAX["test"]["lines"   ]["missed" ] ],
  [ 'test:branches:total',  test_stats['branches']['total' ], '<=', MAX["test"]["branches"]["total"  ] ],
  [ 'test:branches:missed', test_stats['branches']['missed'], '<=', MAX["test"]["branches"]["missed" ] ],
]

# - - - - - - - - - - - - - - - - - - - - - - -
done = []
puts
table.each do |name,value,op,limit|
  #puts "name=#{name}, value=#{value}, op=#{op}, limit=#{limit}"
  result = eval("#{value} #{op} #{limit}")
  puts "%s | %s %s %s | %s" % [
    name.rjust(25), value.to_s.rjust(7), "  #{op}", limit.to_s.rjust(5), coloured(result)
  ]
  done << result
end
puts
exit done.all?
