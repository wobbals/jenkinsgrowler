require 'rubygems'
require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'argumentsparser'

options = JenkinsGrowler::ArgumentsParser.new.parse(ARGV)

$ciBaseUrl = options[:server_url]
$jobs = options[:jobs]
$interval = options[:poll_interval]
 
$jobRuns = Hash.new
 
def last_build_output(job)
  url = URI.parse("#$ciBaseUrl")
  res = Net::HTTP.start(url.host, url.port) { |http|
    http.get("/job/#{job}/lastBuild/api/json")
  }
 
  JSON.parse res.body
end
 
 
def changed_recently(buildTime, job)
  buildRunTime = DateTime.strptime("#{buildTime}+0530", '%Y-%m-%d_%H-%M-%S%z')
  
  if $jobRuns[job] == nil then
    $jobRuns[job] = buildRunTime
    return false
  end
 
  if buildRunTime > $jobRuns[job] then
    $jobRuns[job] = buildRunTime
    return true
  end
  return false
end
 
 
def build_status(job)
  buildOutput = last_build_output job
  puts(buildOutput)
  building = buildOutput['building']
  buildTime = buildOutput['id']
  duration = buildOutput['duration']
 
  if building or !changed_recently(buildTime, job) then
    return
  end
 
  result = buildOutput['result']
  description = buildOutput['fullDisplayName']
  url = buildOutput['url']
 
  comments = ''
  buildOutput['changeSet']['items'].each do |item|
    comments += item['comment']
  end
 
  %x[ growlnotify -t "#{result}" -m "#{description}\n#{comments}" ]
end
 
while true do
  $jobs.each do |job|
    build_status job
  end
 
  sleep $interval 
end
