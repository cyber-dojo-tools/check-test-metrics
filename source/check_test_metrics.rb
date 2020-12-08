
# This scrapes data from three sources
# 1) The minitest stdout which is tee'd to test.log
# 2) The simplecov coverage index.html file.
#    It would be nice if simplecov saved the raw data to a json file
#    and created the html from that, but alas it does not.
#    At the moment its from simplecov 0.17.0
#    Simplecov now supports branch-coverage.
#    However, it breaks my use of two tab groups off the root dir.
#    See https://github.com/colszowka/simplecov/issues/860
# 3) from simplecov 0.19.0 onwards uses coverage.json instead of
#    index.html which is generated from a custom simplecov reporter.
#    See https://github.com/cyber-dojo/differ/blob/master/test/lib/simplecov-json.rb

require 'json'

# - - - - - - - - - - - - - - - - - - - - - - -
def fatal_error(message)
  puts message
  exit(42)
end

# - - - - - - - - - - - - - - - - - - - - - - -
def coverage_code_tab_name
  ENV['COVERAGE_CODE_TAB_NAME']
end

# - - - - - - - - - - - - - - - - - - - - - - -
def coverage_test_tab_name
  ENV['COVERAGE_TEST_TAB_NAME']
end

# - - - - - - - - - - - - - - - - - - - - - - -
def test_log
  $test_log ||= begin
    path = ARGV[0] # eg /test/server/reports/test.log
    cleaned(IO.read(path))
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
def index_html
  $index_html ||= begin
    path = ARGV[1] # eg /test/server/reports/index.html
    cleaned(IO.read(path))
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
def coverage_json
  # Created from SimpleCov custom formatter
  $coverage_json ||= begin
    path = ARGV[2] # eg /test/server/reports/coverage.json
    JSON.parse(IO.read(path))
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
def max_metrics_json
  $max_metrics_json ||= begin
    path = ARGV[3] # eg /test/server/reports/max_metrics.json
    JSON.parse(IO.read(path))
  end
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
def show_args
  p "ARGV[0] == #{ARGV[0]} (test.log)"
  p "ARGV[1] == #{ARGV[1]} (index.html)"
  p "ARGV[2] == #{ARGV[2]} (coverage.json)"
  p "ARGV[3] == #{ARGV[3]} (max_metrics.json)"
  p "ENV['COVERAGE_CODE_TAB_NAME'] == #{coverage_code_tab_name}"
  p "ENV['COVERAGE_TEST_TAB_NAME'] == #{coverage_test_tab_name}"
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
def get_index_stats(name)
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
  stats[:test_count]      = m[1].to_i
  stats[:assertion_count] = m[2].to_i
  stats[:failure_count]   = m[3].to_i
  stats[:error_count]     = m[4].to_i
  stats[:skip_count]      = m[5].to_i

  stats
end

# - - - - - - - - - - - - - - - - - - - - - - -
def safe_divide(nom, denom, name)
  upper = nom[name]
  lower = denom[name]
  if lower === 0
    fail "ERROR (#{name})==0"
  else
    upper.to_f / lower.to_f
  end
end

# - - - - - - - - - - - - - - - - - - - - - - -
log_stats = get_test_log_stats

test_count    = log_stats[:test_count]
failure_count = log_stats[:failure_count]
error_count   = log_stats[:error_count]
warning_count = log_stats[:warning_count]
skip_count    = log_stats[:skip_count]
test_duration = log_stats[:time].to_f

MAX = max_metrics_json

table = [
  [ 'test:failures',    failure_count,  '<=',  MAX["failures"  ] ],
  [ 'test:errors',      error_count,    '<=',  MAX["errors"    ] ],
  [ 'test:warnings',    warning_count,  '<=',  MAX["warnings"  ] ],
  [ 'test:skips',       skip_count,     '<=',  MAX["skips"     ] ],
  [ 'test:duration(s)', test_duration,  '<=',  MAX["duration"  ] ],
]

unless ['0.19.0', '0.19.1'].include?(version)
  table << [ 'test:count', test_count, '>=',  MIN[:test_count] ]
end

test_stats = get_index_stats(coverage_test_tab_name)
app_stats = get_index_stats(coverage_code_tab_name)

if ['0.19.0', '0.19.1'].include?(version)
  table += [
    [ 'app:lines:total',      app_stats['lines'   ]['total' ], '<=', MAX["app"]["lines"   ]["total" ] ],
    [ 'app:lines:missed',     app_stats['lines'   ]['missed'], '<=', MAX["app"]["lines"   ]["missed"] ],
    [ 'app:branches:total',   app_stats['branches']['total' ], '<=', MAX["app"]["branches"]["total" ] ],
    [ 'app:branches:missed',  app_stats['branches']['missed'], '<=', MAX["app"]["branches"]["missed"] ],

    [ 'test:lines:total',     test_stats['lines'   ]['total' ], '<=', MAX["test"]["lines"   ]["total"  ] ],
    [ 'test:lines:missed',    test_stats['lines'   ]['missed'], '<=', MAX["test"]["lines"   ]["missed" ] ],
    [ 'test:branches:total',  test_stats['branches']['total' ], '<=', MAX["test"]["branches"]["total"  ] ],
    [ 'test:branches:missed', test_stats['branches']['missed'], '<=', MAX["test"]["branches"]["missed" ] ],
  ]
else
  tsc = test_stats[:line_count]
  asc = app_stats[:line_count]
  line_ratio = safe_divide(test_stats, app_stats, :line_count)
  table << [ 'lines(test/app)',  f2(line_ratio), '>=',  MIN[:line_ratio] ]

  asr = app_stats[:hits_per_line].to_f
  tsr = test_stats[:hits_per_line].to_f
  hits_ratio = safe_divide(app_stats, test_stats, :hits_per_line)
  table << [ 'hits(app/test)',   f2(hits_ratio), '>=',  MIN[:hits_ratio] ]

  app_coverage  = app_stats[:coverage].to_f
  table << [ ' app:coverage[%]',  app_coverage,  '>=',  MIN[:app_coverage] ]

  test_coverage = test_stats[:coverage].to_f
  table << [ 'test:coverage[%]', test_coverage,  '>=',  MIN[:test_coverage] ]
end

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
