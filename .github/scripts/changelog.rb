#! /usr/bin/ruby
require 'json'

def not_needed?(pr_body)
  pr_body.match(/\[x\]\s+No\s+changelog\s+needed/i)
end

github_event = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))
pr_body = github_event['pull_request']['body']
changes_files = ARGV
puts '-' * 20, "PR Description: #{github_event['pull_request']['body']}"
puts '-' * 20, "Added or modified .changes files: #{changes_files}"

exit(0) unless changes_files.empty?

not_needed?(pr_body) ? exit(0) : exit(1)
