# Copyright (c) 2010-2023 SUSE LLC.
# Licensed under the terms of the MIT license.

### This file contains all step definitions concerning general product funtionality
### as well as those which do not fit into any other category or are temporary workarounds.
###
### The definitions are divided into blocks marked with a summary headline.

require 'jwt'
require 'securerandom'
require 'pathname'

# Used for debugging purposes
When(/^I save a screenshot as "([^"]+)"$/) do |filename|
  save_screenshot(filename)
  attach File.open(filename, 'rb'), 'image/png'
end

When(/^I wait for "(\d+)" seconds?$/) do |arg1|
  sleep(arg1.to_i)
end

When(/^I mount as "([^"]+)" the ISO from "([^"]+)" in the server$/) do |name, url|
  # When using a mirror it is automatically mounted at /mirror
  if $mirror
    iso_path = url.sub(/^http:.*\/pub/, '/mirror/pub')
  else
    iso_path = "/tmp/#{name}.iso"
    $server.run("wget --no-check-certificate -O #{iso_path} #{url}", timeout: 1500)
  end
  mount_point = "/srv/www/htdocs/#{name}"
  $server.run("mkdir -p #{mount_point}")
  $server.run("grep #{iso_path} /etc/fstab || echo '#{iso_path}  #{mount_point}  iso9660  loop,ro,_netdev  0 0' >> /etc/fstab")
  $server.run("umount #{iso_path}; mount #{iso_path}")
end

Then(/^the hostname for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  step %(I should see a "#{node.hostname}" text)
end

Then(/^the kernel for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  kernel_version, _code = node.run('uname -r')
  log 'I should see kernel version: ' + kernel_version
  step %(I should see a "#{kernel_version.strip}" text)
end

Then(/^the OS version for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  os_version = node.os_version
  os_family = node.os_family
  # skip this test for Red Hat-like and Debian-like systems
  step %(I should see a "#{os_version.gsub!('-SP', ' SP')}" text) if os_family.include? 'sles'
end

Then(/^the IPv4 address for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  ipv4_address = node.public_ip
  log "IPv4 address: #{ipv4_address}"
  step %(I should see a "#{ipv4_address}" text)
end

Then(/^the IPv6 address for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  interface, code = node.run("ip -6 address show #{node.public_interface}")
  raise unless code.zero?

  lines = interface.lines
  # selects only lines with IPv6 addresses and proceeds to form an array with only those addresses
  ipv6_addresses_list = lines.grep(/2[:0-9a-f]*|fe80:[:0-9a-f]*/)
  ipv6_addresses_list.map! { |ip_line| ip_line.slice(/2[:0-9a-f]*|fe80:[:0-9a-f]*/) }

  # confirms that the IPv6 address shown on the page is part of that list and, therefore, valid
  ipv6_address = find(:xpath, "//td[text()='IPv6 Address:']/following-sibling::td[1]").text
  log "IPv6 address: #{ipv6_address}"
  raise unless ipv6_addresses_list.include? ipv6_address
end

Then(/^the system ID for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  $api_test.auth.login('admin', 'admin')
  client_id = $api_test.system.search_by_name(get_system_name(host)).first['id']
  $api_test.auth.logout
  step %(I should see a "#{client_id.to_s}" text)
end

Then(/^the system name for "([^"]*)" should be correct$/) do |host|
  node = get_target(host)
  system_name = get_system_name(host)
  step %(I should see a "#{system_name}" text)
end

Then(/^the uptime for "([^"]*)" should be correct$/) do |host|
  uptime = get_uptime_from_host(host)
  # rounded values to nearest integer number
  rounded_uptime_minutes = uptime[:minutes].round
  rounded_uptime_hours = uptime[:hours].round
  # needed for the library's conversion of 24h multiples plus 11 hours to consider the next day
  eleven_hours_in_seconds = 39600 # 11 hours * 60 minutes * 60 seconds
  rounded_uptime_days = ((uptime[:seconds] + eleven_hours_in_seconds) / 86400.0).round # 60 seconds * 60 minutes * 24 hours

  # the moment.js library being used has some weird rules, which these conditionals follow
  if (uptime[:days] >= 1 && rounded_uptime_days < 2) || (uptime[:days] < 1 && rounded_uptime_hours >= 22) # shows "a day ago" after 22 hours and before it's been 1.5 days
    step %(I should see a "a day ago" text)
  elsif rounded_uptime_hours > 1 && rounded_uptime_hours <= 21
    step %(I should see a "#{rounded_uptime_hours} hours ago" text)
  elsif rounded_uptime_minutes >= 45 && rounded_uptime_hours == 1 # shows "an hour ago" from 45 minutes onwards up to 1.5 hours
    step %(I should see a "an hour ago" text)
  elsif rounded_uptime_minutes > 1 && rounded_uptime_hours < 1
    step %(I should see a "#{rounded_uptime_minutes} minutes ago" text)
  elsif uptime[:seconds] >= 45 && rounded_uptime_minutes == 1
    step %(I should see a "a minute ago" text)
  elsif uptime[:seconds] < 45
    step %(I should see a "a few seconds ago" text)
  elsif rounded_uptime_days < 25
    step %(I should see a "#{rounded_uptime_days} days ago" text) # shows "a month ago" from 25 days onwards
  else
    step %(I should see a "a month ago" text)
  end
end

Then(/^I should see several text fields for "([^"]*)"$/) do |host|
  node = get_target(host)
  steps %(Then I should see a "UUID" text
    And I should see a "Virtualization" text
    And I should see a "Installed Products" text
    And I should see a "Checked In" text
    And I should see a "Registered" text
    And I should see a "Contact Method" text
    And I should see a "Auto Patch Update" text
    And I should see a "Maintenance Schedule" text
    And I should see a "Description" text
    And I should see a "Location" text
  )
end

# events

When(/^I wait until event "([^"]*)" is completed$/) do |event|
  step %(I wait at most #{DEFAULT_TIMEOUT} seconds until event "#{event}" is completed)
end

When(/^I wait (\d+) seconds until the event is picked up and (\d+) seconds until the event "([^"]*)" is completed$/) do |pickup_timeout, complete_timeout, event|
  # The code below is not perfect because there might be other events with the
  # same name in the events history - however, that's the best we have so far.
  steps %(
    When I follow "Events"
    And I follow "Pending"
    And I wait at most #{pickup_timeout} seconds until I do not see "#{event}" text, refreshing the page
    And I follow "History"
    And I wait until I see "System History" text
    And I wait until I see "#{event}" text, refreshing the page
    And I follow first "#{event}"
    And I wait at most #{complete_timeout} seconds until the event is completed, refreshing the page
  )
end

When(/^I wait at most (\d+) seconds until event "([^"]*)" is completed$/) do |final_timeout, event|
  step %(I wait 90 seconds until the event is picked up and #{final_timeout} seconds until the event "#{event}" is completed)
end

When(/^I wait until I see the event "([^"]*)" completed during last minute, refreshing the page$/) do |event|
  repeat_until_timeout(message: "Couldn't find the event #{event}") do
    now = Time.now
    current_minute = now.strftime('%H:%M')
    previous_minute = (now - 60).strftime('%H:%M')
    begin
      break if find(:xpath, "//a[contains(text(),'#{event}')]/../..//td[4]/time[contains(text(),'#{current_minute}') or contains(text(),'#{previous_minute}')]/../../td[3]/a[1]", wait: 1)
    rescue Capybara::ElementNotFound
      # ignored - pending actions cannot be found
    end
    begin
      accept_prompt do
        execute_script 'window.location.reload()'
      end
    rescue Capybara::ModalNotFound
      # ignored
    end
  end
end

When(/^I follow the event "([^"]*)" completed during last minute$/) do |event|
  now = Time.now
  current_minute = now.strftime('%H:%M')
  previous_minute = (now - 60).strftime('%H:%M')
  xpath_query = "//a[contains(text(), '#{event}')]/../..//td[4]/time[contains(text(),'#{current_minute}') or contains(text(),'#{previous_minute}')]/../../td[3]/a[1]"
  element = find_and_wait_click(:xpath, xpath_query)
  element.click
end

# spacewalk errors steps
Then(/^the up2date logs on client should contain no Traceback error$/) do
  cmd = 'if grep "Traceback" /var/log/up2date ; then exit 1; else exit 0; fi'
  _out, code = $client.run(cmd)
  raise 'error found, check the client up2date logs' if code.nonzero?
end

# action chains
When(/^I check radio button "(.*?)"$/) do |arg1|
  raise "#{arg1} can't be checked" unless choose(arg1)
end

When(/^I enter as remote command this script in$/) do |multiline|
  find(:xpath, '//textarea[@name="script_body"]').set(multiline)
end

# bare metal
When(/^I check the ram value$/) do
  get_ram_value = "grep MemTotal /proc/meminfo |awk '{print $2}'"
  ram_value, _local, _remote, _code = $client.test_and_store_results_together(get_ram_value, 'root', 600)
  ram_value = ram_value.gsub(/\s+/, '')
  ram_mb = ram_value.to_i / 1024
  step %(I should see a "#{ram_mb}" text)
end

When(/^I check the MAC address value$/) do
  get_mac_address = 'cat /sys/class/net/eth0/address'
  mac_address, _local, _remote, _code = $client.test_and_store_results_together(get_mac_address, 'root', 600)
  mac_address = mac_address.gsub(/\s+/, '')
  mac_address.downcase!
  step %(I should see a "#{mac_address}" text)
end

Then(/^I should see the CPU frequency of the client$/) do
  get_cpu_freq = "lscpu  | grep 'CPU MHz'" # | awk '{print $4}'"
  cpu_freq, _local, _remote, _code = $client.test_and_store_results_together(get_cpu_freq, 'root', 600)
  get_cpu = cpu_freq.gsub(/\s+/, '')
  cpu = get_cpu.split('.')
  cpu = cpu[0].gsub(/[^\d]/, '')
  step %(I should see a "#{cpu.to_i / 1000} GHz" text)
end

Then(/^I should see the power is "([^"]*)"$/) do |status|
  within(:xpath, "//*[@for='powerStatus']/..") do
    repeat_until_timeout(message: "power is not #{status}") do
      break if has_content?(status)
      find(:xpath, '//button[@value="Get status"]').click
    end
    raise "Power status #{status} not found" unless has_content?(status)
  end
end

When(/^I select "(.*?)" as the origin channel$/) do |label|
  step %(I select "#{label}" from "original_id")
end

# systemspage
Given(/^I am on the Systems page$/) do
  steps %(
    And I follow the left menu "Systems > Overview"
    And I wait until I see "System Overview" text
  )
end

When(/^I attach the file "(.*)" to "(.*)"$/) do |path, field|
  canonical_path = Pathname.new(File.join(File.dirname(__FILE__), '/../upload_files/', path)).cleanpath
  attach_file(field, canonical_path)
end

When(/^I refresh the metadata for "([^"]*)"$/) do |host|
  node = get_target(host)
  os_family = node.os_family
  if os_family =~ /^opensuse/ || os_family =~ /^sles/
    node.run_until_ok('zypper --non-interactive refresh -s')
  elsif os_family =~ /^centos/
    node.run('yum clean all && yum makecache', timeout: 600)
  elsif os_family =~ /^ubuntu/
    node.run('apt-get update')
  else
    raise "The host #{host} has not yet a implementation for that step"
  end
end

Then(/^channel "([^"]*)" should be enabled on "([^"]*)"$/) do |channel, host|
  node = get_target(host)
  node.run("zypper lr -E | grep '#{channel}'")
end

Then(/^channel "([^"]*)" should not be enabled on "([^"]*)"$/) do |channel, host|
  node = get_target(host)
  _out, code = node.run("zypper lr -E | grep '#{channel}'", check_errors: false)
  raise "'#{channel}' was not expected but was found." if code.to_i.zero?
end

Then(/^"(\d+)" channels should be enabled on "([^"]*)"$/) do |count, host|
  node = get_target(host)
  node.run("zypper lr -E | tail -n +5", verbose: true)
  out, _code = node.run("zypper lr -E | tail -n +5 | wc -l")
  raise "Expected #{count} channels enabled but found #{out}." unless count.to_i == out.to_i
end

Then(/^"(\d+)" channels with prefix "([^"]*)" should be enabled on "([^"]*)"$/) do |count, prefix, host|
  node = get_target(host)
  node.run("zypper lr -E | tail -n +5 | grep '#{prefix}'", verbose: true)
  out, _code = node.run("zypper lr -E | tail -n +5 | grep '#{prefix}' | wc -l")
  raise "Expected #{count} channels enabled but found #{out}." unless count.to_i == out.to_i
end

# metadata steps
# these steps currently work only for traditional clients
Then(/^I should have '([^']*)' in the metadata for "([^"]*)"$/) do |text, host|
  raise 'Invalid target.' unless host == 'sle_client'
  target = $client
  arch, _code = target.run('uname -m')
  arch.chomp!
  cmd = "zgrep '#{text}' #{client_raw_repodata_dir('fake-rpm-suse-channel')}/*primary.xml.gz"
  target.run(cmd, timeout: 500)
end

Then(/^I should not have '([^']*)' in the metadata for "([^"]*)"$/) do |text, host|
  raise 'Invalid target.' unless host == 'sle_client'
  target = $client
  arch, _code = target.run('uname -m')
  arch.chomp!
  cmd = "zgrep '#{text}' #{client_raw_repodata_dir('fake-rpm-suse-channel')}/*primary.xml.gz"
  target.run(cmd, timeout: 500)
end

Then(/^"([^"]*)" should exist in the metadata for "([^"]*)"$/) do |file, host|
  raise 'Invalid target.' unless host == 'sle_client'
  node = $client
  arch, _code = node.run('uname -m')
  arch.chomp!
  dir_file = client_raw_repodata_dir("fake-rpm-suse-channel")
  _out, code = node.run("ls -1 #{dir_file}/*#{file} 2>/dev/null")
  raise "File #{dir_file}/*#{file} not exist" unless _out.lines.count >= 1
end

Then(/^I should have '([^']*)' in the patch metadata for "([^"]*)"$/) do |text, host|
  node = get_target(host)
  arch, _code = node.run('uname -m')
  arch.chomp!
  # TODO: adapt for architectures
  cmd = "zgrep '#{text}' /var/cache/zypp/raw/spacewalk:fake-rpm-suse-channel/repodata/*updateinfo.xml.gz"
  node.run(cmd, timeout: 500)
end

# package steps
Then(/^I should see package "([^"]*)"$/) do |package|
  step %(I should see a "#{package}" text)
end

Given(/^metadata generation finished for "([^"]*)"$/) do |channel|
  $server.run_until_ok("ls /var/cache/rhn/repodata/#{channel}/*updateinfo.xml.gz")
end

And(/^I push package "([^"]*)" into "([^"]*)" channel$/) do |arg1, arg2|
  srvurl = "http://#{ENV['SERVER']}/APP"
  command = "rhnpush --server=#{srvurl} -u admin -p admin --nosig -c #{arg2} #{arg1} "
  $server.run(command, timeout: 500)
  $server.run('ls -lR /var/spacewalk/packages', timeout: 500)
end

Then(/^I should see package "([^"]*)" in channel "([^"]*)"$/) do |pkg, channel|
  steps %(
    When I follow the left menu "Software > Channel List > All"
    And I follow "#{channel}"
    And I follow "Packages"
    Then I should see package "#{pkg}"
  )
end

When(/^I schedule a task to update ReportDB$/) do
  steps %(
    When I follow the left menu "Admin > Task Schedules"
    And I follow "update-reporting-default"
    And I follow "mgr-update-reporting-bunch"
    And I click on "Single Run Schedule"
    Then I should see a "bunch was scheduled" text
    And I wait until the table contains "FINISHED" or "SKIPPED" followed by "FINISHED" in its first rows
  )
end
