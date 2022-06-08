# Copyright (c) 2010-2022 SUSE LLC.
# Licensed under the terms of the MIT license.

require 'jwt'
require 'securerandom'
require 'pathname'

When(/^I save a screenshot as "([^"]+)"$/) do |filename|
  save_screenshot(filename)
  attach File.open(filename, 'rb'), 'image/png'
end

When(/^I wait for "(\d+)" seconds?$/) do |arg1|
  sleep(arg1.to_i)
end

When(/^I mount as "([^"]+)" the ISO from "([^"]+)" in the server$/) do |name, url|
  iso_path = "/tmp/#{name}.iso"
  mount_point = "/srv/www/htdocs/#{name}"
  $server.run("wget --no-check-certificate -O #{iso_path} #{url}", timeout: 500)
  $server.run("mkdir -p #{mount_point}")
  $server.run("grep #{iso_path} /etc/fstab || echo '#{iso_path}  #{mount_point}  iso9660  loop,ro  0 0' >> /etc/fstab")
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
  os_version, os_family = get_os_version(node)
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
  ipv6_addresses_list = lines.grep(/2620:[:0-9a-f]*|fe80:[:0-9a-f]*/)
  ipv6_addresses_list.map! { |ip_line| ip_line.slice(/2620:[:0-9a-f]*|fe80:[:0-9a-f]*/) }

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

When(/^I wait at most (\d+) seconds until event "([^"]*)" is completed$/) do |final_timeout, event|
  # The code below is not perfect because there might be other events with the
  # same name in the events history - however, that's the best we have so far.
  steps %(
    When I follow "Events"
    And I follow "Pending"
    And I wait at most 90 seconds until I do not see "#{event}" text, refreshing the page
    And I follow "History"
    And I wait until I see "System History" text
    And I wait until I see "#{event}" text, refreshing the page
    And I follow first "#{event}"
    And I wait at most #{final_timeout} seconds until the event is completed, refreshing the page
  )
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

# salt failures log check
Then(/^the salt event log on server should contain no failures$/) do
  # upload salt event parser log
  file = 'salt_event_parser.py'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($server, source, dest)
  raise 'File injection failed' unless return_code.zero?
  # print failures from salt event log
  output, _code = $server.run("python3 /tmp/#{file}")
  count_failures = output.to_s.scan(/false/).length
  output = output.join.to_s if output.respond_to?(:join)
  raise "\nFound #{count_failures} failures in salt event log:\n#{output}\n" if count_failures.nonzero?
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
  get_cpu_freq = "cat /proc/cpuinfo  | grep -i 'CPU MHz'" # | awk '{print $4}'"
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

# systemspage and clobber
Given(/^I am on the Systems page$/) do
  steps %(
    And I follow the left menu "Systems > Overview"
    And I wait until I see "System Overview" text
  )
end

Given(/^cobblerd is running$/) do
  ct = CobblerTest.new
  raise 'cobblerd is not running' unless ct.running?
end

Then(/^create distro "([^"]*)" as user "([^"]*)" with password "([^"]*)"$/) do |distro, user, pwd|
  ct = CobblerTest.new
  ct.login(user, pwd)
  raise 'distro ' + distro + ' already exists' if ct.distro_exists(distro)
  ct.distro_create(distro, '/var/autoinstall/SLES15-SP4-x86_64/DVD1/boot/x86_64/loader/linux', '/var/autoinstall/SLES15-SP4-x86_64/DVD1/boot/x86_64/loader/initrd')
end

Then(/^create profile "([^"]*)" for distro "([^"]*)" as user "([^"]*)" with password "([^"]*)"$/) do |profile, distro, user, pwd|
  ct = CobblerTest.new
  ct.login(user, pwd)
  raise 'profile ' + profile + ' already exists' if ct.profile_exists(profile)
  ct.profile_create(profile, distro, '/var/autoinstall/mock/empty.xml')
end

Then(/^create system "([^"]*)" for profile "([^"]*)" as user "([^"]*)" with password "([^"]*)"$/) do |system, profile, user, pwd|
  ct = CobblerTest.new
  ct.login(user, pwd)
  raise 'system ' + system + ' already exists' if ct.system_exists(system)
  ct.system_create(system, profile)
end

Then(/^remove system "([^"]*)" as user "([^"]*)" with password "([^"]*)"$/) do |system, user, pwd|
  ct = CobblerTest.new
  ct.login(user, pwd)
  ct.system_remove(system)
end

When(/^I trigger cobbler system record$/) do
  # not for SSH-push traditional client
  space = 'spacecmd -u admin -p admin'
  host = $client.full_hostname
  $server.run("#{space} clear_caches")
  out, _code = $server.run("#{space} system_details #{host}")
  unless out.include? 'ssh-push-tunnel'
    # normal traditional client
    steps %(
      Given I am authorized as "testing" with password "testing"
      And I follow this "sle_client" link
      And I follow "Provisioning"
      And I click on "Create PXE installation configuration"
      And I click on "Continue"
      And I wait until file "/srv/tftpboot/pxelinux.cfg/01-*" contains "ks=" on server
    )
  end
end

Given(/^distro "([^"]*)" exists$/) do |distro|
  ct = CobblerTest.new
  raise 'distro ' + distro + ' does not exist' unless ct.distro_exists(distro)
end

Given(/^profile "([^"]*)" exists$/) do |profile|
  ct = CobblerTest.new
  raise 'profile ' + profile + ' does not exist' unless ct.profile_exists(profile)
end

Given(/^system "([^"]*)" exists$/) do |system|
  ct = CobblerTest.new
  raise 'system ' + system + ' does not exist' unless ct.system_exists(system)
end

When(/^I remove kickstart profiles and distros$/) do
  host = $server.full_hostname
  $api_test.auth.login('admin', 'admin')
  # -------------------------------
  # Cleanup kickstart distros and their profiles, if any.

  # Get all distributions: created from UI or from API.
  distros = $server.run('cobbler distro list')[0].split

  # The name of distros created in the UI has the form: distro_label + suffix
  user_details = $api_test.user.get_details('testing')
  suffix = ":#{user_details['org_id']}:#{user_details['org_name'].delete(' ')}"

  distros_ui = distros.select { |distro| distro.end_with? suffix }.map { |distro| distro.split(':')[0] }
  distros_api = distros.reject { |distro| distro.end_with? suffix }
  distros_ui.each { |distro| $api_test.kickstart.tree.delete_tree_and_profiles(distro) }
  # -------------------------------
  # Remove profiles and distros created with the API.

  # We have already deleted the profiles from the UI; delete all the remaning ones.
  profiles = $server.run('cobbler profile list')[0].split
  profiles.each { |profile| $server.run("cobbler profile remove --name '#{profile}'") }
  distros_api.each { |distro| $server.run("cobbler distro remove --name '#{distro}'") }
  $api_test.auth.logout
end

When(/^I attach the file "(.*)" to "(.*)"$/) do |path, field|
  canonical_path = Pathname.new(File.join(File.dirname(__FILE__), '/../upload_files/', path)).cleanpath
  attach_file(field, canonical_path)
end

When(/^I refresh the metadata for "([^"]*)"$/) do |host|
  node = get_target(host)
  _os_version, os_family = get_os_version(node)
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
  _out, code = node.run("zypper lr -E | tail -n +5 | wc -l")
  raise "Expected #{count} channels enabled but found #{_out}." unless count.to_i == _out.to_i
end

Then(/^"(\d+)" channels with prefix "([^"]*)" should be enabled on "([^"]*)"$/) do |count, prefix, host|
  node = get_target(host)
  _out, code = node.run("zypper lr -E | tail -n +5 | grep '#{prefix}' | wc -l")
  raise "Expected #{count} channels enabled but found #{_out}." unless count.to_i == _out.to_i
end

# metadata steps
# these steps currently work only for traditional clients
Then(/^I should have '([^']*)' in the metadata for "([^"]*)"$/) do |text, host|
  raise 'Invalid target.' unless host == 'sle_client'
  target = $client
  arch, _code = target.run('uname -m')
  arch.chomp!
  cmd = "zgrep '#{text}' #{client_raw_repodata_dir("test-channel-#{arch}")}/*primary.xml.gz"
  target.run(cmd, timeout: 500)
end

Then(/^I should not have '([^']*)' in the metadata for "([^"]*)"$/) do |text, host|
  raise 'Invalid target.' unless host == 'sle_client'
  target = $client
  arch, _code = target.run('uname -m')
  arch.chomp!
  cmd = "zgrep '#{text}' #{client_raw_repodata_dir("test-channel-#{arch}")}/*primary.xml.gz"
  target.run(cmd, timeout: 500)
end

Then(/^"([^"]*)" should exist in the metadata for "([^"]*)"$/) do |file, host|
  raise 'Invalid target.' unless host == 'sle_client'
  node = $client
  arch, _code = node.run('uname -m')
  arch.chomp!
  dir_file = client_raw_repodata_dir("test-channel-#{arch}")
  _out, code = node.run("ls -1 #{dir_file}/*#{file} 2>/dev/null")
  raise "File #{dir_file}/*#{file} not exist" unless _out.lines.count >= 1
end

Then(/^I should have '([^']*)' in the patch metadata$/) do |text|
  arch, _code = $client.run('uname -m')
  arch.chomp!
  cmd = "zgrep '#{text}' #{client_raw_repodata_dir("test-channel-#{arch}")}/*updateinfo.xml.gz"
  $client.run(cmd, timeout: 500)
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

# setup wizard

Then(/^HTTP proxy verification should have succeeded$/) do
  raise 'Success icon not found' unless find('i.text-success', wait: DEFAULT_TIMEOUT)
end

When(/^I enter the address of the HTTP proxy as "([^"]*)"$/) do |hostname|
  step %(I enter "#{$server_http_proxy}" as "#{hostname}")
end

When(/^I ask to add new credentials$/) do
  raise 'Click on plus icon failed' unless find('i.fa-plus-circle').click
end

When(/^I enter the SCC credentials$/) do
  scc_username, scc_password = ENV['SCC_CREDENTIALS'].split('|')
  steps %(
    And I enter "#{scc_username}" as "edit-user"
    And I enter "#{scc_password}" as "edit-password"
  )
end

Then(/^the SCC credentials should be valid$/) do
  scc_username, scc_password = ENV['SCC_CREDENTIALS'].split('|')
  within(:xpath, "//h3[contains(text(), '#{scc_username}')]/../..") do
    raise 'Success icon not found' unless find('i.text-success', wait: DEFAULT_TIMEOUT)
  end
end

Then(/^the credentials for "([^"]*)" should be invalid$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    raise 'Failure icon not found' unless find('i.text-danger', wait: DEFAULT_TIMEOUT)
  end
end

When(/^I make the credentials for "([^"]*)" primary$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    raise 'Click on star icon failed' unless find('i.fa-star-o').click
  end
end

Then(/^the credentials for "([^"]*)" should be primary$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    raise 'Star icon not selected' unless find('i.fa-star')
  end
end

When(/^I wait for the trash icon to appear for "([^"]*)"$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    repeat_until_timeout(message: 'Trash icon is still greyed out') do
      break unless find('i.fa-trash-o')[:style].include? "not-allowed"
      sleep 1
    end
  end
end

When(/^I ask to delete the credentials for "([^"]*)"$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    raise 'Click on trash icon failed' unless find('i.fa-trash-o').click
  end
end

When(/^I view the subscription list for "([^"]*)"$/) do |user|
  within(:xpath, "//h3[contains(text(), '#{user}')]/../..") do
    raise 'Click on list icon failed' unless find('i.fa-th-list').click
  end
end

And(/^I select "(.*?)" in the dropdown list of the architecture filter$/) do |architecture|
  # let the the select2js box filter open the hidden options
  xpath_query = "//div[@id='s2id_product-arch-filter']/ul/li/input"
  raise "xpath: #{xpath_query} not found" unless find(:xpath, xpath_query).click
  # select the desired option
  raise "Architecture #{architecture} not found" unless find(:xpath, "//div[@id='select2-drop']/ul/li/div[contains(text(), '#{architecture}')]").click
end

When(/^I enter the "(.*)" package in the css "(.*)"$/) do |client, css|
  find(css).set(PACKAGE_BY_CLIENT[client])
end

When(/^I (deselect|select) "([^\"]*)" as a product$/) do |select, product|
  # click on the checkbox to select the product
  xpath = "//span[contains(text(), '#{product}')]/ancestor::div[contains(@class, 'product-details-wrapper')]/div/input[@type='checkbox']"
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath).set(select == "select")
end

When(/^I (deselect|select) "([^\"]*)" as a (SUSE Manager|Uyuni) product$/) do |select, product, product_version|
  if $product == product_version
    step %(I #{select} "#{product}" as a product)
  end
end

When(/^I wait at most (\d+) seconds until the tree item "([^"]+)" has no sub-list$/) do |timeout, item|
  repeat_until_timeout(timeout: timeout.to_i, message: "could still find a sub list for tree item #{item}") do
    xpath = "//span[contains(text(), '#{item}')]/ancestor::div[contains(@class, 'product-details-wrapper')]/div/i[contains(@class, 'fa-angle-')]"
    begin
      find(:xpath, xpath)
      sleep 1
    rescue Capybara::ElementNotFound
      break
    end
  end
end

When(/^I wait at most (\d+) seconds until the tree item "([^"]+)" contains "([^"]+)" text$/) do |timeout, item, text|
  within(:xpath, "//span[contains(text(), '#{item}')]/ancestor::div[contains(@class, 'product-details-wrapper')]") do
    raise "could not find text #{text} for tree item #{item}" unless has_text?(text, wait: timeout.to_i)
  end
end

When(/^I wait at most (\d+) seconds until the tree item "([^"]+)" contains "([^"]+)" button$/) do |timeout, item, button|
  xpath_query = "//span[contains(text(), '#{item}')]/"\
      "ancestor::div[contains(@class, 'product-details-wrapper')]/descendant::*[@title='#{button}']"
  raise "xpath: #{xpath_query} not found" unless find(:xpath, xpath_query, wait: timeout.to_i)
end

When(/^I open the sub-list of the product "(.*?)" on (SUSE Manager|Uyuni)$/) do |product, product_version|
  if $product == product_version
    step %(I open the sub-list of the product "#{product}")
  end
end

When(/^I open the sub-list of the product "(.*?)"$/) do |product|
  xpath = "//span[contains(text(), '#{product}')]/ancestor::div[contains(@class, 'product-details-wrapper')]/div/i[contains(@class, 'fa-angle-right')]"
  # within(:xpath, xpath) do
  #   raise unless find('i.fa-angle-down').click
  # end
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath).click
end

When(/^I select the addon "(.*?)"$/) do |addon|
  # click on the checkbox of the sublist to select the addon product
  xpath = "//span[contains(text(), '#{addon}')]/ancestor::div[contains(@class, 'product-details-wrapper')]/div/input[@type='checkbox']"
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath).set(true)
end

And(/^I should see that the "(.*?)" product is "(.*?)"$/) do |product, recommended|
  xpath = "//span[text()[normalize-space(.) = '#{product}'] and ./span/text() = '#{recommended}']"
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath)
end

Then(/^I should see the "(.*?)" selected$/) do |product|
  xpath = "//span[contains(text(), '#{product}')]/ancestor::div[contains(@class, 'product-details-wrapper')]"
  within(:xpath, xpath) do
    raise "#{find(:xpath, '.')['data-identifier']} is not checked" unless find(:xpath, "./div/input[@type='checkbox']").checked?
  end
end

And(/^I wait until I see "(.*?)" product has been added$/) do |product|
  repeat_until_timeout(message: "Couldn't find the installed product #{product} in the list") do
    xpath = "//span[contains(text(), '#{product}')]/ancestor::div[contains(@class, 'product-details-wrapper')]"
    begin
      product_class = find(:xpath, xpath)[:class]
      unless product_class.nil?
        break if product_class.include?('product-installed')
      end
    rescue Capybara::ElementNotFound => e
      log e
    end
    sleep 1
  end
end

When(/^I click the Add Product button$/) do
  raise "xpath: button#addProducts not found" unless find('button#addProducts').click
end

Then(/^the SLE12 SP5 product should be added$/) do
  output, _code = $server.run('echo -e "admin\nadmin\n" | mgr-sync list channels', check_errors: false, buffer_size: 1_000_000)
  raise unless output.include? '[I] SLES12-SP5-Pool for x86_64 SUSE Linux Enterprise Server 12 SP5 x86_64 [sles12-sp5-pool-x86_64]'
  if $product != 'Uyuni'
    raise unless output.include? '[I] SLE-Manager-Tools12-Pool for x86_64 SP5 SUSE Linux Enterprise Server 12 SP5 x86_64 [sle-manager-tools12-pool-x86_64-sp5]'
  end
  raise unless output.include? '[I] SLE-Module-Legacy12-Updates for x86_64 Legacy Module 12 x86_64 [sle-module-legacy12-updates-x86_64-sp5]'
end

Then(/^the SLE15 (SP3|SP4) product should be added$/) do |sp_version|
  output, _code = $server.run('echo -e "admin\nadmin\n" | mgr-sync list channels', check_errors: false, buffer_size: 1_000_000)
  raise unless output.include? "[I] SLE-Product-SLES15-#{sp_version}-Pool for x86_64 SUSE Linux Enterprise Server 15 #{sp_version} x86_64 [sle-product-sles15-#{sp_version.downcase}-pool-x86_64]"
  raise unless output.include? "[I] SLE-Module-Basesystem15-#{sp_version}-Updates for x86_64 Basesystem Module 15 #{sp_version} x86_64 [sle-module-basesystem15-#{sp_version.downcase}-updates-x86_64]"
  raise unless output.include? "[I] SLE-Module-Server-Applications15-#{sp_version}-Pool for x86_64 Server Applications Module 15 #{sp_version} x86_64 [sle-module-server-applications15-#{sp_version.downcase}-pool-x86_64]"
end

When(/^I click the channel list of product "(.*?)"$/) do |product|
  xpath = "//span[contains(text(), '#{product}')]/ancestor::div[contains(@class, 'product-details-wrapper')]/div/button[contains(@class, 'showChannels')]"
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath).click
end

# configuration management steps

Then(/^I should see a table line with "([^"]*)", "([^"]*)", "([^"]*)"$/) do |arg1, arg2, arg3|
  within(:xpath, "//div[@class=\"table-responsive\"]/table/tbody/tr[.//td[contains(.,'#{arg1}')]]") do
    raise "Link #{arg2} not found" unless find_link(arg2)
    raise "Link #{arg3} not found" unless find_link(arg3)
  end
end

Then(/^I should see a table line with "([^"]*)", "([^"]*)"$/) do |arg1, arg2|
  within(:xpath, "//div[@class=\"table-responsive\"]/table/tbody/tr[.//td[contains(.,'#{arg1}')]]") do
    raise "Link #{arg2} not found" unless find_link(arg2)
  end
end

Then(/^a table line should contain system "([^"]*)", "([^"]*)"$/) do |host, text|
  system_name = get_system_name(host)
  within(:xpath, "//div[@class=\"table-responsive\"]/table/tbody/tr[.//td[contains(.,'#{system_name}')]]") do
    raise "Text #{text} not found" unless find_all(:xpath, "//td[contains(., '#{text}')]")
  end
end

# generic file management steps

When(/^I destroy "([^"]*)" directory on server$/) do |directory|
  $server.run("rm -rf #{directory}")
end

When(/^I destroy "([^"]*)" directory on "([^"]*)"$/) do |directory, host|
  node = get_target(host)
  node.run("rm -rf #{directory}")
end

When(/^I remove "([^"]*)" from "([^"]*)"$/) do |filename, host|
  node = get_target(host)
  file_delete(node, filename)
end

Then(/^file "([^"]*)" should exist on server$/) do |filename|
  $server.run("test -f #{filename}")
end

Then(/^file "([^"]*)" should exist on "([^"]*)"$/) do |filename, host|
  node = get_target(host)
  node.run("test -f #{filename}")
end

Then(/^file "([^"]*)" should have ([0-9]+) permissions on "([^"]*)"$/) do |filename, permissions, host|
  node = get_target(host)
  node.run("test \"`stat -c '%a' #{filename}`\" = \"#{permissions}\"")
end

Then(/^file "([^"]*)" should not exist on server$/) do |filename|
  $server.run("test ! -f #{filename}")
end

Then(/^file "([^"]*)" should not exist on "([^"]*)"$/) do |filename, host|
  node = get_target(host)
  node.run("test ! -f #{filename}")
end

When(/^I store "([^"]*)" into file "([^"]*)" on "([^"]*)"$/) do |content, filename, host|
  node = get_target(host)
  node.run("echo \"#{content}\" > #{filename}", timeout: 600)
end

# rubocop:disable Metrics/BlockLength
When(/^I bootstrap (traditional|minion) client "([^"]*)" using bootstrap script with activation key "([^"]*)" from the (server|proxy)$/) do |client_type, host, key, target_type|
  # Use server if proxy is not defined as proxy is not mandatory
  target = $proxy
  if target_type.include? 'server' or $proxy.nil?
    log 'WARN: Bootstrapping to server, because proxy is not defined.' unless target_type.include? 'server'
    target = $server
  end

  # Prepare bootstrap script for different types of clients
  client = client_type == 'traditional' ? '--traditional' : ''
  force_bundle = $use_salt_bundle ? '--force-bundle' : ''

  node = get_target(host)
  gpg_keys = get_gpg_keys(node, target)
  cmd = "mgr-bootstrap #{client} #{force_bundle} &&
  sed -i s\'/^exit 1//\' /srv/www/htdocs/pub/bootstrap/bootstrap.sh &&
  sed -i '/^ACTIVATION_KEYS=/c\\ACTIVATION_KEYS=#{key}' /srv/www/htdocs/pub/bootstrap/bootstrap.sh &&
  chmod 644 /srv/www/htdocs/pub/RHN-ORG-TRUSTED-SSL-CERT &&
  sed -i '/^ORG_GPG_KEY=/c\\ORG_GPG_KEY=#{gpg_keys.join(',')}' /srv/www/htdocs/pub/bootstrap/bootstrap.sh &&
  cat /srv/www/htdocs/pub/bootstrap/bootstrap.sh"
  output, = target.run(cmd)
  unless output.include? key
    log output
    raise "Key: #{key} not included"
  end

  # Run bootstrap script and check for result
  boostrap_script = 'bootstrap-general.exp'
  source = File.dirname(__FILE__) + '/../upload_files/' + boostrap_script
  dest = '/tmp/' + boostrap_script
  return_code = file_inject(target, source, dest)
  raise 'File injection failed' unless return_code.zero?
  system_name = get_system_name(host)
  output, = target.run("expect -f /tmp/#{boostrap_script} #{system_name}")
  unless output.include? '-bootstrap complete-'
    log output
    raise "Bootstrap didn't finish properly"
  end
end
# rubocop:enable Metrics/BlockLength

Then(/^file "([^"]*)" should contain "([^"]*)" on "([^"]*)"$/) do |filename, content, host|
  node = get_target(host)
  node.run("test -f #{filename}")
  node.run("grep \"#{content}\" #{filename}")
end

Then(/^I remove server hostname from hosts file on "([^"]*)"$/) do |host|
  node = get_target(host)
  node.run("sed -i \'s/#{$server.full_hostname}//\' /etc/hosts")
end

# Repository steps

# Enable tools repositories (both stable and development)
When(/^I enable client tools repositories on "([^"]*)"$/) do |host|
  node = get_target(host)
  _os_version, os_family = get_os_version(node)
  case os_family
  when /^(opensuse|sles)/
    repos, _code = node.run('zypper lr | grep "tools" | cut -d"|" -f2')
    node.run("zypper mr --enable #{repos.gsub(/\s/, ' ')}")
  when /^centos/
    repos, _code = node.run('yum repolist disabled 2>/dev/null | grep "tools" | cut -d" " -f1')
    repos.gsub(/\s/, ' ').split.each do |repo|
      node.run("sed -i 's/enabled=.*/enabled=1/g' /etc/yum.repos.d/#{repo}.repo")
    end
  when /^ubuntu/
    repos, _code = node.run("ls /etc/apt/sources.list.d | grep tools")
    repos.gsub(/\s/, ' ').split.each do |repo|
      node.run("sed -i '/^#\\s*deb.*/ s/^#\\s*deb /deb /' /etc/apt/sources.list.d/#{repo}")
    end
  else
    raise "This step has no implementation for #{os_family} system."
  end
end

When(/^I disable client tools repositories on "([^"]*)"$/) do |host|
  node = get_target(host)
  _os_version, os_family = get_os_version(node)
  case os_family
  when /^(opensuse|sles)/
    repos, _code = node.run('zypper lr | grep "tools" | cut -d"|" -f2')
    node.run("zypper mr --disable #{repos.gsub(/\s/, ' ')}")
  when /^centos/
    repos, _code = node.run('yum repolist enabled 2>/dev/null | grep "tools" | cut -d" " -f1')
    repos.gsub(/\s/, ' ').split.each do |repo|
      node.run("sed -i 's/enabled=.*/enabled=0/g' /etc/yum.repos.d/#{repo}.repo")
    end
  when /^ubuntu/
    repos, _code = node.run("ls /etc/apt/sources.list.d | grep tools")
    repos.gsub(/\s/, ' ').split.each do |repo|
      node.run("sed -i '/^deb.*/ s/^deb /# deb /' /etc/apt/sources.list.d/#{repo}")
    end
  else
    raise "This step has no implementation for #{os_family} system."
  end
end

When(/^I enable repositories before installing Docker$/) do
  os_version, os_family = get_os_version($build_host)

  # Distribution
  repos = "os_pool_repo os_update_repo"
  log $build_host.run("zypper mr --enable #{repos}")

  # Tools
  repos, _code = $build_host.run('zypper lr | grep "tools" | cut -d"|" -f2')
  log $build_host.run("zypper mr --enable #{repos.gsub(/\s/, ' ')}")

  # Development and Desktop Applications (required)
  # (we do not install Python 2 repositories in this branch
  #  because they are not needed anymore starting with version 4.1)
  if os_family =~ /^sles/ && os_version =~ /^15/
    repos = "devel_pool_repo devel_updates_repo desktop_pool_repo desktop_updates_repo"
    log $build_host.run("zypper mr --enable #{repos}")
  end

  # Containers
  unless os_family =~ /^opensuse/ || os_version =~ /^11/
    repos = "containers_pool_repo containers_updates_repo"
    log $build_host.run("zypper mr --enable #{repos}")
  end

  $build_host.run('zypper -n --gpg-auto-import-keys ref')
end

When(/^I disable repositories after installing Docker$/) do
  os_version, os_family = get_os_version($build_host)

  # Distribution
  repos = "os_pool_repo os_update_repo"
  log $build_host.run("zypper mr --disable #{repos}")

  # Tools
  repos, _code = $build_host.run('zypper lr | grep "tools" | cut -d"|" -f2')
  log $build_host.run("zypper mr --disable #{repos.gsub(/\s/, ' ')}")

  # Development and Desktop Applications (required)
  # (we do not install Python 2 repositories in this branch
  #  because they are not needed anymore starting with version 4.1)
  if os_family =~ /^sles/ && os_version =~ /^15/
    repos = "devel_pool_repo devel_updates_repo desktop_pool_repo desktop_updates_repo"
    log $build_host.run("zypper mr --disable #{repos}")
  end

  # Containers
  unless os_family =~ /^opensuse/ || os_version =~ /^11/
    repos = "containers_pool_repo containers_updates_repo"
    log $build_host.run("zypper mr --disable #{repos}")
  end
end

# Register client
Given(/^I update the profile of this client$/) do
  step %(I update the profile of "sle_client")
end

Given(/^I update the profile of "([^"]*)"$/) do |client|
  node = get_target(client)
  node.run('rhn-profile-sync', timeout: 500)
end

When(/^I register using "([^"]*)" key$/) do |key|
  step %(I register "sle_client" as traditional client with activation key "#{key}")
end

When(/^I register "([^"]*)" as traditional client$/) do |client|
  step %(I register "#{client}" as traditional client with activation key "1-SUSE-KEY-x86_64")
end

And(/^I register "([^*]*)" as traditional client with activation key "([^*]*)"$/) do |client, key|
  node = get_target(client)
  if client.include? 'sle'
    node.run('zypper --non-interactive install wget', timeout: 500)
  else # As Debian-like has no support for traditional clients, it must be Red Hat-like
    node.run('yum install wget', timeout: 600)
  end
  registration_url = if $proxy.nil?
                       "https://#{$server.full_hostname}/XMLRPC"
                     else
                       "https://#{$proxy.full_hostname}/XMLRPC"
                     end
  command1 = "wget --no-check-certificate -O /usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT http://#{$server.full_hostname}/pub/RHN-ORG-TRUSTED-SSL-CERT"
  # Replace unicode chars \xHH with ? in the output (otherwise, they might break Cucumber formatters).
  log node.run(command1, timeout: 500).to_s.gsub(/(\\x\h+){1,}/, '?')
  command2 = "rhnreg_ks --force --serverUrl=#{registration_url} --sslCACert=/usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT --activationkey=#{key}"
  log node.run(command2, timeout: 500).to_s.gsub(/(\\x\h+){1,}/, '?')
end

When(/^I wait until onboarding is completed for "([^"]*)"((?: salt minion)?)$/) do |host, is_salt|
  steps %(
    When I follow the left menu "Systems > Overview"
    And I wait until I see the name of "#{host}", refreshing the page
    And I follow this "#{host}" link
  )
  if get_client_type(host) == 'traditional' and is_salt.empty?
    get_target(host).run('rhn_check -vvv')
  else
    steps %(
      And I wait at most 500 seconds until event "Hardware List Refresh" is completed
      And I wait at most 500 seconds until event "Apply states" is completed
      And I wait at most 500 seconds until event "Package List Refresh" is completed
    )
  end
end

Then(/^I should see "([^"]*)" via spacecmd$/) do |host|
  command = "spacecmd -u admin -p admin system_list"
  system_name = get_system_name(host)
  repeat_until_timeout(message: "system #{system_name} is not in the list yet") do
    $server.run("spacecmd -u admin -p admin clear_caches")
    result, code = $server.run(command, check_errors: false)
    break if result.include? system_name
    sleep 1
  end
end

Then(/^I should see "([^"]*)" as link$/) do |host|
  system_name = get_system_name(host)
  step %(I should see a "#{system_name}" link)
end

Then(/^I should see a text describing the OS release$/) do
  _os_version, os_family = get_os_version($client)
  release = os_family =~ /^opensuse/ ? 'openSUSE-release' : 'sles-release'
  step %(I should see a "OS: #{release}" text)
end

When(/^I remember when I scheduled an action$/) do
  moment = "schedule_action"
  val = DateTime.now
  if defined?($moments)
    $moments[moment] = val
  else
    $moments = {moment => val}
  end
end

Then(/^I should see "([^"]*)" at least (\d+) minutes after I scheduled an action$/) do |text, minutes|
  # TODO is there a better way then page.all ?
  elements = all('div', text: text)
  raise "Text #{text} not found in the page" if elements.nil?
  match = elements[0].text.match(/#{text}\s*(\d+\/\d+\/\d+ \d+:\d+:\d+ (AM|PM)+ [^\s]+)/)
  raise "No element found matching text '#{text}'" if match.nil?
  text_time = DateTime.strptime("#{match.captures[0]}", '%m/%d/%C %H:%M:%S %p %Z')
  raise "Time the action was scheduled not found in memory" unless defined?($moments) and $moments["schedule_action"]
  initial = $moments["schedule_action"]
  after = initial + Rational(1, 1440) * minutes.to_i
  raise "#{text_time.to_s} is not #{minutes} minutes later than '#{initial.to_s}'" unless (text_time + Rational(1, 1440)) >= after
end

# Valid claims:
#   - org
#   - onlyChannels
def token(secret, claims = {})
  payload = {}
  payload.merge!(claims)
  log secret
  JWT.encode payload, [secret].pack('H*').bytes.to_a.pack('c*'), 'HS256'
end

def server_secret
  rhnconf, _code = $server.run('cat /etc/rhn/rhn.conf', check_errors: false)
  data = /server.secret_key\s*=\s*(\h+)$/.match(rhnconf)
  data[1].strip
end

Given(/^I have a valid token for organization "([^"]*)"$/) do |org|
  @token = token(server_secret, org: org.to_i)
end

Given(/^I have an invalid token for organization "([^"]*)"$/) do |org|
  @token = token(SecureRandom.hex(64), org: org.to_i)
end

Given(/^I have an expired valid token for organization "([^"]*)"$/) do |org|
  yesterday = Time.now.to_i - 86_400
  @token = token(server_secret, org: org.to_i, exp: yesterday)
end

Given(/^I have a valid token expiring tomorrow for organization "([^"]*)"$/) do |org|
  tomorrow = Time.now.to_i + 86_400
  @token = token(server_secret, org: org.to_i, exp: tomorrow)
end

Given(/^I have a not yet usable valid token for organization "([^"]*)"$/) do |org|
  tomorrow = Time.now.to_i + 86_400
  @token = token(server_secret, org: org.to_i, nbf: tomorrow)
end

Given(/^I have a valid token for organization "(.*?)" and channel "(.*?)"$/) do |org, channel|
  @token = token(server_secret, org: org, onlyChannels: [channel])
end

And(/^I should see the toggler "([^"]*)"$/) do |target_status|
  case target_status
  when 'enabled'
    xpath = "//i[contains(@class, 'fa-toggle-on')]"
    raise "xpath: #{xpath} not found" unless find(:xpath, xpath)
  when 'disabled'
    xpath = "//i[contains(@class, 'fa-toggle-off')]"
    raise "xpath: #{xpath} not found" unless find(:xpath, xpath)
  else
    raise 'Invalid target status.'
  end
end

And(/^I click on the "([^"]*)" toggler$/) do |target_status|
  case target_status
  when 'enabled'
    xpath = "//i[contains(@class, 'fa-toggle-on')]"
    raise "xpath: #{xpath} not found" unless find(:xpath, xpath).click
  when 'disabled'
    xpath = "//i[contains(@class, 'fa-toggle-off')]"
    raise "xpath: #{xpath} not found" unless find(:xpath, xpath).click
  else
    raise 'Invalid target status.'
  end
end

And(/^I should see the child channel "([^"]*)" "([^"]*)"$/) do |target_channel, target_status|
  step %(I should see a "#{target_channel}" text)

  xpath = "//label[contains(text(), '#{target_channel}')]"
  channel_checkbox_id = find(:xpath, xpath)['for']

  case target_status
  when 'selected'
    raise "#{channel_checkbox_id} is not selected" unless has_checked_field?(channel_checkbox_id)
  when 'unselected'
    raise "#{channel_checkbox_id} is selected" if has_checked_field?(channel_checkbox_id)
  else
    raise 'Invalid target status.'
  end
end

And(/^I should see the child channel "([^"]*)" "([^"]*)" and "([^"]*)"$/) do |target_channel, target_status, is_disabled|
  step %(I should see a "#{target_channel}" text)

  xpath = "//label[contains(text(), '#{target_channel}')]"
  channel_checkbox_id = find(:xpath, xpath)['for']
  "disabled".eql?(is_disabled) || raise('Invalid disabled flag value')

  case target_status
  when 'selected'
    raise "#{channel_checkbox_id} is not selected" unless has_checked_field?(channel_checkbox_id, disabled: true)
  when 'unselected'
    raise "#{channel_checkbox_id} is selected" if has_checked_field?(channel_checkbox_id, disabled: true)
  else
    raise 'Invalid target status.'
  end
end

And(/^I select the child channel "([^"]*)"$/) do |target_channel|
  step %(I should see a "#{target_channel}" text)

  xpath = "//label[contains(text(), '#{target_channel}')]"
  channel_checkbox_id = find(:xpath, xpath)['for']

  raise "Field #{channel_checkbox_id} is checked" if has_checked_field?(channel_checkbox_id)
  find(:xpath, "//input[@id='#{channel_checkbox_id}']").click
end

And(/^I should see "([^"]*)" "([^"]*)" for the "([^"]*)" channel$/) do |target_radio, target_status, target_channel|
  xpath = "//a[contains(text(), '#{target_channel}')]"
  channel_id = find(:xpath, xpath)['href'].split('?')[1].split('=')[1]

  case target_radio
  when 'No change'
    xpath = "//input[@type='radio' and @name='ch_action_#{channel_id}' and @value='NO_CHANGE']"
  when 'Subscribe'
    xpath = "//input[@type='radio' and @name='ch_action_#{channel_id}' and @value='SUBSCRIBE']"
  when 'Unsubscribe'
    xpath = "//input[@type='radio' and @name='ch_action_#{channel_id}' and @value='UNSUBSCRIBE']"
  end

  case target_status
  when 'selected'
    raise "xpath: #{xpath} is not selected" if find(:xpath, xpath)['checked'].nil?
  when 'unselected'
    raise "xpath: #{xpath} is selected" unless find(:xpath, xpath)['checked'].nil?
  end
end

And(/^the notification badge and the table should count the same amount of messages$/) do
  table_notifications_count = count_table_items

  badge_xpath = "//i[contains(@class, 'fa-bell')]/following-sibling::*[text()='#{table_notifications_count}']"

  if table_notifications_count == '0'
    log "All notification-messages are read, I expect no notification badge"
    raise "xpath: #{badge_xpath} found" if has_xpath?(badge_xpath)
  else
    log "Unread notification-messages count = " + table_notifications_count
    raise "xpath: #{badge_xpath} not found" unless find(:xpath, badge_xpath)
  end
end

And(/^I wait until radio button "([^"]*)" is checked, refreshing the page$/) do |arg1|
  unless has_checked_field?(arg1)
    repeat_until_timeout(message: "Couldn't find checked radio button #{arg1}") do
      break if has_checked_field?(arg1)
      begin
        accept_prompt do
          execute_script 'window.location.reload()'
        end
      rescue Capybara::ModalNotFound
        # ignored
      end
    end
  end
end

Then(/^I check the first notification message$/) do
  if count_table_items == '0'
    log "There are no notification messages, nothing to do then"
  else
    within(:xpath, '//section') do
      row = find(:xpath, "//div[@class=\"table-responsive\"]/table/tbody/tr[.//td]", match: :first)
      row.find(:xpath, './/input[@type="checkbox"]', match: :first).set(true)
    end
  end
end

And(/^I delete it via the "([^"]*)" button$/) do |target_button|
  if count_table_items != '0'
    xpath_for_delete_button = "//button[@title='#{target_button}']"
    raise "xpath: #{xpath_for_delete_button} not found" unless find(:xpath, xpath_for_delete_button).click

    step %(I wait until I see "1 message deleted successfully." text)
  end
end

And(/^I mark as read it via the "([^"]*)" button$/) do |target_button|
  if count_table_items != '0'
    xpath_for_read_button = "//button[@title='#{target_button}']"
    raise "xpath: #{xpath_for_read_button} not found" unless find(:xpath, xpath_for_read_button).click

    step %(I wait until I see "1 message read status updated successfully." text)
  end
end

When(/^I remove package "([^"]*)" from highstate$/) do |package|
  event_table_xpath = "//div[@class='table-responsive']/table/tbody"
  rows = find(:xpath, event_table_xpath)
  rows.all('tr').each do |tr|
    next unless tr.text.include?(package)
    log tr.text
    tr.find("##{package}-pkg-state").select('Removed')
    next if has_css?('#save[disabled]')
    steps %(
      Then I click on "Save"
      And I click on "Apply"
    )
  end
end

When(/^I check for failed events on history event page$/) do
  steps %(
    When I follow "Events" in the content area
    And I follow "History" in the content area
    Then I should see a "System History" text
  )
  failings = ""
  event_table_xpath = "//div[@class='table-responsive']/table/tbody"
  rows = find(:xpath, event_table_xpath)
  rows.all('tr').each do |tr|
    if tr.all(:css, '.fa.fa-times-circle-o.fa-1-5x.text-danger').any?
      failings << "#{tr.text}\n"
    end
  end
  count_failures = failings.length
  raise "\nFailures in event history found:\n\n#{failings}" if count_failures.nonzero?
end

Then(/^I should see a list item with text "([^"]*)" and a (success|failing|warning|pending|refreshing) bullet$/) do |text, bullet_type|
  item_xpath = "//ul/li[text()='#{text}']/i[contains(@class, '#{BULLET_STYLE[bullet_type]}')]"
  find(:xpath, item_xpath)
end

When(/^I create the MU repositories for "([^"]*)"$/) do |client|
  repo_list = $custom_repositories[client]
  next if repo_list.nil?

  repo_list.each do |_repo_name, repo_url|
    unique_repo_name = generate_repository_name(repo_url)
    if repository_exist? unique_repo_name
      log "The MU repository #{unique_repo_name} was already created, we will reuse it."
    else
      content_type = deb_host?(client) ? 'deb' : 'yum'
      steps %(
        When I follow the left menu "Software > Manage > Repositories"
        And I follow "Create Repository"
        And I enter "#{unique_repo_name}" as "label"
        And I enter "#{repo_url.strip}" as "url"
        And I select "#{content_type}" from "contenttype"
        And I click on "Create Repository"
        Then I should see a "Repository created successfully" text or "The repository label '#{unique_repo_name}' is already in use" text
        And I should see "metadataSigned" as checked
      )
    end
  end
end

When(/^I select the MU repositories for "([^"]*)" from the list$/) do |client|
  repo_list = $custom_repositories[client]
  next if repo_list.nil?

  repo_list.each do |_repo_name, repo_url|
    unique_repo_name = generate_repository_name(repo_url)
    step %(I check "#{unique_repo_name}" in the list)
  end
end

# content lifecycle steps
When(/^I click the environment build button$/) do
  raise 'Click on environment build failed' unless find_button('cm-build-modal-save-button', disabled: false, wait: DEFAULT_TIMEOUT).click
end

When(/^I click promote from Development to QA$/) do
  raise 'Click on promote from Development failed' unless find_button('dev_label-promote-modal-link', disabled: false, wait: DEFAULT_TIMEOUT).click
end

When(/^I click promote from QA to Production$/) do
  raise 'Click on promote from QA failed' unless find_button('qa_label-promote-modal-link', disabled: false, wait: DEFAULT_TIMEOUT).click
end

Then(/^I should see a "([^"]*)" text in the environment "([^"]*)"$/) do |text, env|
  within(:xpath, "//h3[text()='#{env}']/../..") do
    raise "Text \"#{text}\" not found" unless has_content?(text)
  end
end

When(/^I wait at most (\d+) seconds until I see "([^"]*)" text in the environment "([^"]*)"$/) do |seconds, text, env|
  within(:xpath, "//h3[text()='#{env}']/../..") do
    step %(I wait at most #{seconds} seconds until I see "#{text}" text)
  end
end

When(/^I wait until I see "([^"]*)" text in the environment "([^"]*)"$/) do |text, env|
  within(:xpath, "//h3[text()='#{env}']/../..") do
    raise "Text \"#{text}\" not found" unless has_text?(text, wait: DEFAULT_TIMEOUT)
  end
end

When(/^I add the "([^"]*)" channel to sources$/) do |channel|
  within(:xpath, "//span[text()='#{channel}']/../..") do
    raise "Add channel failed" unless find(:xpath, './/input[@type="checkbox"]').set(true)
  end
end

When(/^I click the "([^\"]*)" item (.*?) button$/) do |name, action|
  button = case action
           when /details/ then "i[contains(@class, 'fa-list')]"
           when /edit/ then "i[contains(@class, 'fa-edit')]"
           when /delete/ then "i[contains(@class, 'fa-trash')]"
           else raise "Unknown element with description '#{action}'"
           end
  xpath = "//td[contains(text(), '#{name}')]/ancestor::tr/td/div/button/#{button}"
  raise "xpath: #{xpath} not found" unless find(:xpath, xpath).click
end

When(/^I backup the SSH authorized_keys file of host "([^"]*)"$/) do |host|
  # authorized_keys paths on the client
  auth_keys_path = '/root/.ssh/authorized_keys'
  auth_keys_sav_path = '/root/.ssh/authorized_keys.sav'
  target = get_target(host)
  _, ret_code = target.run("cp #{auth_keys_path} #{auth_keys_sav_path}")
  raise 'error backing up authorized_keys on host' if ret_code.nonzero?
end

And(/^I add pre\-generated SSH public key to authorized_keys of host "([^"]*)"$/) do |host|
  key_filename = 'id_rsa_bootstrap-passphrase_linux.pub'
  target = get_target(host)
  ret_code = file_inject(
    target,
    File.dirname(__FILE__) + '/../upload_files/ssh_keypair/' + key_filename,
    '/tmp/' + key_filename
  )
  target.run("cat /tmp/#{key_filename} >> /root/.ssh/authorized_keys", timeout: 500)
  raise 'Error copying ssh pubkey to host' if ret_code.nonzero?
end

When(/^I restore the SSH authorized_keys file of host "([^"]*)"$/) do |host|
  # authorized_keys paths on the client
  auth_keys_path = '/root/.ssh/authorized_keys'
  auth_keys_sav_path = '/root/.ssh/authorized_keys.sav'
  target = get_target(host)
  target.run("cp #{auth_keys_sav_path} #{auth_keys_path}")
  target.run("rm #{auth_keys_sav_path}")
end

When(/^I add "([^\"]*)" calendar file as url$/) do |file|
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/srv/www/htdocs/pub/" + file
  return_code = file_inject($server, source, dest)
  raise 'File injection failed' unless return_code.zero?
  $server.run("chmod 644 #{dest}")
  url = "http://#{$server.full_hostname}/pub/" + file
  log "URL: #{url}"
  step %(I enter "#{url}" as "calendar-data-text")
end

When(/^I deploy testing playbooks and inventory files to "([^"]*)"$/) do |host|
  target = get_target(host)
  dest = "/srv/playbooks/orion_dummy/"
  target.run("mkdir -p #{dest}")
  source = File.dirname(__FILE__) + '/../upload_files/ansible/playbooks/orion_dummy/playbook_orion_dummy.yml'
  return_code = file_inject(target, source, dest + "playbook_orion_dummy.yml")
  raise 'File injection failed' unless return_code.zero?
  source = File.dirname(__FILE__) + '/../upload_files/ansible/playbooks/orion_dummy/hosts'
  return_code = file_inject(target, source, dest + "hosts")
  raise 'File injection failed' unless return_code.zero?
  source = File.dirname(__FILE__) + '/../upload_files/ansible/playbooks/orion_dummy/file.txt'
  return_code = file_inject(target, source, dest + "file.txt")
  raise 'File injection failed' unless return_code.zero?
  dest = "/srv/playbooks/"
  source = File.dirname(__FILE__) + '/../upload_files/ansible/playbooks/playbook_ping.yml'
  return_code = file_inject(target, source, dest + "playbook_ping.yml")
  raise 'File injection failed' unless return_code.zero?
end

When(/^I remove testing playbooks and inventory files from "([^"]*)"$/) do |host|
  playbooks_dir = 'ansible/'
  target = get_target(host)
  dest = "/srv/playbooks/"
  target.run("rm -rf #{dest}")
end

When(/^I enter the reactivation key of "([^"]*)"$/) do |host|
  system_name = get_system_name(host)
  $api_test.auth.login('admin', 'admin')
  node_id = $api_test.system.retrieve_server_id(system_name)
  react_key = $api_test.system.obtain_reactivation_key(node_id)
  $api_test.auth.logout
  log "Reactivation Key: #{react_key}"
  step %(I enter "#{react_key}" as "reactivationKey")
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

Then(/^port "([^"]*)" should be (open|closed)$/) do |port, selection|
  _output, code = $server.run("ss --listening --numeric | grep :#{port}", check_errors: false, verbose: true)
  port_opened = code.zero?
  if selection == 'closed'
    raise "Port '#{port}' open although it should not be!" if port_opened
  else
    raise "Port '#{port}' not open although it should be!" unless port_opened
  end
end

When(/^I prepare Cobbler for the buildiso command$/) do
  tmp_dir = "/var/cache/cobbler/buildiso"
  $server.run("mkdir -p #{tmp_dir}")
  # we need bootloaders for the buildiso command
  out, code = $server.run("cobbler mkloaders", verbose: true)
  raise "error in cobbler mkloaders.\nLogs:\n#{out}" if code.nonzero?
end

When(/^I run Cobbler buildiso for distro "([^"]*)" and all profiles$/) do |distro|
  tmp_dir = "/var/cache/cobbler/buildiso"
  iso_dir = "/var/cache/cobbler"
  out, code = $server.run("cobbler buildiso --tempdir=#{tmp_dir} --iso #{iso_dir}/profile_all.iso --distro=#{distro}", verbose: true)
  raise "error in cobbler buildiso.\nLogs:\n#{out}" if code.nonzero?
  profiles = ['orchid', 'flame', 'pearl']
  isolinux_profiles = []
  cobbler_profiles = []
  profiles.each do |profile|
    # get all profiles from Cobbler
    result_cobbler, code = $server.run("cobbler profile list | grep -o #{profile}", verbose: true)
    cobbler_profiles.push(result_cobbler) if code.zero?
    # get all profiles from isolinux.cfg
    result_isolinux, code = $server.run("cat #{tmp_dir}/isolinux/isolinux.cfg | grep -o #{profile} | cut -c -6 | head -n 1")
    unless result_isolinux.empty?
      isolinux_profiles.push(result_isolinux)
    end
  end
  raise "error during comparison of Cobbler profiles.\nLogs:\nCobbler profiles:\n#{cobbler_profiles}\nisolinux profiles:\n#{isolinux_profiles}" unless cobbler_profiles == isolinux_profiles
end

When(/^I run Cobbler buildiso for distro "([^"]*)" and profile "([^"]*)"$/) do |distro, profile|
  tmp_dir = "/var/cache/cobbler/buildiso"
  iso_dir = "/var/cache/cobbler"
  out, code = $server.run("cobbler buildiso --tempdir=#{tmp_dir} --iso #{iso_dir}/#{profile}.iso --distro=#{distro} --profile=#{profile}", verbose: true)
  raise "error in cobbler buildiso.\nLogs:\n#{out}" if code.nonzero?
end

When(/^I run Cobbler buildiso for distro "([^"]*)" and profile "([^"]*)" without dns entries$/) do |distro, profile|
  tmp_dir = "/var/cache/cobbler/buildiso"
  iso_dir = "/var/cache/cobbler"
  out, code = $server.run("cobbler buildiso --tempdir=#{tmp_dir} --iso #{iso_dir}/#{profile}.iso --distro=#{distro} --profile=#{profile} --exclude-dns", verbose: true)
  raise "error in cobbler buildiso.\nLogs:\n#{out}" if code.nonzero?
  result, code = $server.run("cat #{tmp_dir}/isolinux/isolinux.cfg | grep -o nameserver")
  # we have to fail here if the command suceeds
  raise "error in Cobbler buildiso, nameserver parameter found in isolinux.cfg but should not be found.\nLogs:\n#{result}" if code.zero?
end

When(/^I run Cobbler buildiso "([^"]*)" for distro "([^"]*)"$/) do |param, distro|
  # param can either be standalone or airgapped
  # workaround to get the contents of the buildiso folder
  step %(I run Cobbler buildiso for distro "#{distro}" and all profiles)
  tmp_dir = "/var/cache/cobbler/buildiso"
  iso_dir = "/var/cache/cobbler"
  source_dir = "/var/cache/cobbler/source_#{param}"
  $server.run("mv #{tmp_dir} #{source_dir}")
  $server.run("mkdir -p #{tmp_dir}")
  out, code = $server.run("cobbler buildiso --tempdir=#{tmp_dir} --iso #{iso_dir}/#{param}.iso --distro=#{distro} --#{param} --source=#{source_dir}", verbose: true)
  raise "error in cobbler buildiso.\nLogs:\n#{out}" if code.nonzero?
end

When(/^I check Cobbler buildiso ISO "([^"]*)" with xorriso$/) do |name|
  tmp_dir = "/var/cache/cobbler"
  out, code = $server.run("cat >#{tmp_dir}/test_image <<-EOF
BIOS
UEFI
EOF")
  xorriso = "xorriso -indev #{tmp_dir}/#{name}.iso -report_el_torito 2>/dev/null"
  iso_filter = "awk '/^El Torito boot img[[:space:]]+:[[:space:]]+[0-9]+[[:space:]]+[a-zA-Z]+[[:space:]]+y/{print $7}'"
  iso_file = "#{tmp_dir}/xorriso_#{name}"
  out, code = $server.run("#{xorriso} | #{iso_filter} >> #{iso_file}")
  raise "error while executing xorriso.\nLogs:\n#{out}" if code.nonzero?
  out, code = $server.run("diff #{tmp_dir}/test_image #{tmp_dir}/xorriso_#{name}")
  raise "error in verifying Cobbler buildiso image with xorriso.\nLogs:\n#{out}" if code.nonzero?
end

Then(/^I add the Cobbler parameter "([^"]*)" with value "([^"]*)" to item "(distro|profile|system)" with name "([^"]*)"$/) do |param, value, item, name|
  result, code = $server.run("cobbler #{item} edit --name=#{name} --#{param}=#{value}", verbose: true)
  puts("cobbler #{item} edit --name #{name} #{param}=#{value}")
  raise "error in adding parameter and value to Cobbler #{item}.\nLogs:\n#{result}" if code.nonzero?
end

And(/^I check the Cobbler parameter "([^"]*)" with value "([^"]*)" in the isolinux.cfg$/) do |param, value|
  tmp_dir = "/var/cache/cobbler/buildiso"
  result, code = $server.run("cat #{tmp_dir}/isolinux/isolinux.cfg | grep -o #{param}=#{value}")
  raise "error during veryfying isolinux.cfg parameter for Cobbler buildiso.\nLogs:\n#{result}" if code.nonzero?
end

When(/^I cleanup after Cobbler buildiso$/) do
  result, code = $server.run("rm -Rf /var/cache/cobbler")
  raise "error during Cobbler buildiso cleanup.\nLogs:\n#{result}" if code.nonzero?
end
