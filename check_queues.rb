#!/opt/ruby/bin/ruby

require 'rubygems'
require 'getoptlong'

def get_queues
  queuelist = `rabbitmqctl -q list_queues`
  resultarray = queuelist.split(/\n/)
  resulthash = {}
  resultarray.each do |line|
    queue,messages = line.split(/\t/)
    resulthash[queue] = messages
  end
  resulthash
end


opts = GetoptLong.new(
  ['--warn', '-w', GetoptLong::REQUIRED_ARGUMENT],
  ['--crit', '-c', GetoptLong::REQUIRED_ARGUMENT])
  
conf = {:warn => 10, :crit => 20}

opts.each do |opt,arg|
  case opt
  when "--warn"
    conf[:warn] = arg.to_i
  when "--crit"
    conf[:crit] = arg.to_i
  end
end

queues = get_queues
results = {:errors => [], :warnings => [], :ok => []}
queues.each do |queue, messages|
  if messages.to_i >= conf[:crit]
    results[:errors].push "#{queue}:#{messages}"
  elsif messages.to_i >= conf[:warn]
    results[:warnings].push "#{queue}:#{messages}"
  else
    results[:ok].push "#{queue}:#{messages}"
  end
end

if results[:errors].count > 0
  printf "%s\n", "CRIT: Some queues have excessive messages. #{results[:errors].join(' ')}"
  exit 2
elsif results[:warnings].count > 0
  printf "%s\n", "WARN: Some queues have excessive messages. #{results[:errors].join(' ')}"
  exit 1
else
  printf "%s\n", "OK: All queues within limits. #{results[:ok].join(' ')}"
  exit 0
end
