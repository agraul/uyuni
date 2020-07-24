# Copyright (c) 2014-2020 SUSE LLC.
# Licensed under the terms of the MIT license.

require 'xmlrpc/client'
require 'timeout'

# Sanity checks

Then(/^"([^"]*)" should have a FQDN$/) do |host|
  node = get_target(host)
  result, return_code = node.run('hostname -f')
  result.delete!("\n")
  raise 'cannot determine hostname' unless return_code.zero?
  raise 'hostname is not fully qualified' unless result == node.full_hostname
end

Then(/^"([^"]*)" should communicate with the server$/) do |host|
  node = get_target(host)
  node.run("ping -c1 #{$server.full_hostname}")
  $server.run("ping -c1 #{node.full_hostname}")
end

Then(/^the clock from "([^"]*)" should be exact$/) do |host|
  node = get_target(host)
  clock_node, _rc = node.run("date +'%s'")
  clock_controller = `date +'%s'`
  difference = clock_node.to_i - clock_controller.to_i
  raise "clocks differ by #{difference} seconds" unless difference.abs < 2
end

Then(/^it should be possible to reach the test packages$/) do
  url = 'https://download.opensuse.org/repositories/systemsmanagement:/Uyuni:/Test-Packages:/Updates/rpm/x86_64/orion-dummy-1.1-1.1.x86_64.rpm'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

Then(/^it should be possible to reach the build sources$/) do
  url = 'http://download.suse.de/ibs/SUSE/Products/SLE-SERVER/12-SP4/x86_64/product/media.1/products.key'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

Then(/^it should be possible to reach the container profiles$/) do
  url = 'https://gitlab.suse.de/galaxy/suse-manager-containers/blob/master/test-profile/Dockerfile'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

Then(/^it should be possible to reach the test suite profiles$/) do
  url = 'https://github.com/uyuni-project/uyuni/blob/master/testsuite/features/profiles/Docker/Dockerfile'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

Then(/^it should be possible to reach the portus registry$/) do
  url = 'https://portus.mgr.suse.de:5000'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

Then(/^it should be possible to reach the other registry$/) do
  url = 'https://registry.mgr.suse.de:443'
  $server.run("curl --insecure --location #{url} --output /dev/null")
end

# Channels

When(/^I delete these channels with spacewalk\-remove\-channel:$/) do |table|
  channels_cmd = "spacewalk-remove-channel "
  table.raw.each { |x| channels_cmd = channels_cmd + " -c " + x[0] }
  $command_output, return_code = $server.run(channels_cmd, false)
end

When(/^I list channels with spacewalk\-remove\-channel$/) do
  $command_output, return_code = $server.run("spacewalk-remove-channel -l")
  raise "Unable to run spacewalk-remove-channel -l command on server" unless return_code.zero?
end

# Packages

Then(/^"([^"]*)" should be installed on "([^"]*)"$/) do |package, host|
  node = get_target(host)
  node.run("rpm -q #{package}")
end

Then(/^Deb package "([^"]*)" with version "([^"]*)" should be installed on "([^"]*)"$/) do |package, version, host|
  node = get_target(host)
  node.run("test $(dpkg-query -W -f='${Version}' #{package}) = \"#{version}\"")
end

Then(/^"([^"]*)" should not be installed on "([^"]*)"$/) do |package, host|
  node = get_target(host)
  node.run("rpm -q #{package}; test $? -ne 0")
end

When(/^I wait for "([^"]*)" to be (uninstalled|installed) on "([^"]*)"$/) do |package, status, host|
  node = get_target(host)
  if host.include? 'ubuntu'
    node.wait_while_process_running('apt-get')
    pkg_version = package.split('-')[-1]
    pkg_name = package.delete_suffix("-#{pkg_version}")
    pkg_version_regexp = pkg_version.gsub('.', '\\.')
    if status == 'installed'
      node.run_until_ok("dpkg -l | grep -E '^ii +#{pkg_name} +#{pkg_version_regexp} +'")
    else
      node.run_until_fail("dpkg -l | grep -E '^ii +#{pkg_name} +#{pkg_version_regexp} +'")
    end
  else
    node.wait_while_process_running('zypper')
    if status == 'installed'
      node.run_until_ok("rpm -q #{package}")
    else
      node.run_until_fail("rpm -q #{package}")
    end
  end
end

When(/^I query latest Salt changes on "(.*?)"$/) do |host|
  node = get_target(host)
  result, return_code = node.run("LANG=en_US.UTF-8 rpm -q --changelog salt")
  result.split("\n")[0, 15].each do |line|
    line.force_encoding("UTF-8")
    puts line
  end
end

When(/^I query latest Salt changes on ubuntu system "(.*?)"$/) do |host|
  node = get_target(host)
  result, return_code = node.run("zcat /usr/share/doc/salt-minion/changelog.Debian.gz")
  result.split("\n")[0, 15].each do |line|
    line.force_encoding("UTF-8")
    puts line
  end
end

When(/^I apply highstate on "([^"]*)"$/) do |host|
  system_name = get_system_name(host)
  if host.include? 'ssh_minion'
    cmd = 'runuser -u salt -- salt-ssh --priv=/srv/susemanager/salt/salt_ssh/mgr_ssh_id'
    extra_cmd = '-i --roster-file=/tmp/roster_tests -w -W'
    $server.run("printf '#{system_name}:\n  host: #{system_name}\n  user: root\n  passwd: linux\n' > /tmp/roster_tests")
  elsif host.include? 'minion' or host.include? 'build_host'
    cmd = 'salt'
    extra_cmd = ''
  end
  $server.run_until_ok("cd /tmp; #{cmd} #{system_name} state.highstate #{extra_cmd}")
end

Then(/^I wait until "([^"]*)" service is active on "([^"]*)"$/) do |service, host|
  node = get_target(host)
  cmd = "systemctl is-active #{service}"
  node.run_until_ok(cmd)
end

When(/^I enable product "([^"]*)"$/) do |prd|
  list_output = sshcmd("mgr-sync list products", ignore_err: true)[:stdout]
  executed = false
  linenum = 0
  list_output.each_line do |line|
    next unless /^ *\[ \]/ =~ line
    linenum += 1
    next unless line.include? prd
    executed = true
    $command_output = sshcmd("echo '#{linenum}' | mgr-sync add product", ignore_err: true)[:stdout]
    break
  end
  raise $command_output.to_s unless executed
end

When(/^I enable product "([^"]*)" without recommended$/) do |prd|
  list_output = sshcmd("mgr-sync list products", ignore_err: true)[:stdout]
  executed = false
  linenum = 0
  list_output.each_line do |line|
    next unless /^ *\[ \]/ =~ line
    linenum += 1
    next unless line.include? prd
    executed = true
    $command_output = sshcmd("echo '#{linenum}' | mgr-sync add product --no-recommends", ignore_err: true)[:stdout]
    break
  end
  raise $command_output.to_s unless executed
end

When(/^I execute mgr\-sync "([^"]*)" with user "([^"]*)" and password "([^"]*)"$/) do |arg1, u, p|
  $command_output = sshcmd("echo -e '#{u}\n#{p}\n' | mgr-sync #{arg1}", ignore_err: true)[:stdout]
end

When(/^I execute mgr\-sync "([^"]*)"$/) do |arg1|
  $command_output = sshcmd("mgr-sync #{arg1}")[:stdout]
end

When(/^I remove the mgr\-sync cache file$/) do
  $command_output = sshcmd('rm -f ~/.mgr-sync')[:stdout]
end

When(/^I refresh SCC$/) do
  refresh_timeout = 600
  $server.run('echo -e "admin\nadmin\n" | mgr-sync refresh', true, refresh_timeout)
end

When(/^I execute mgr\-sync refresh$/) do
  $command_output = sshcmd('mgr-sync refresh', ignore_err: true)[:stderr]
end

When(/^I make sure no spacewalk\-repo\-sync is executing, excepted the ones needed to bootstrap$/) do
  do_not_kill = compute_list_to_leave_running
  reposync_not_running_streak = 0
  reposync_left_running_streak = 0
  while reposync_not_running_streak <= 30 && reposync_left_running_streak <= 7200
    command_output, _code = $server.run('ps axo pid,cmd | grep spacewalk-repo-sync | grep -v grep', false)
    if command_output.empty?
      reposync_not_running_streak += 1
      reposync_left_running_streak = 0
      sleep 1
      next
    end
    reposync_not_running_streak = 0

    process = command_output.split("\n")[0]
    channel = process.split(' ')[5]
    if do_not_kill.include? channel
      STDOUT.puts "Reposync of channel #{channel} left running" if (reposync_left_running_streak % 60).zero?
      reposync_left_running_streak += 1
      sleep 1
      next
    end
    reposync_left_running_streak = 0

    pid = process.split(' ')[0]
    $server.run("kill #{pid}", false)
    STDOUT.puts "Reposync of channel #{channel} killed"
  end
end

When(/^I execute mgr\-bootstrap "([^"]*)"$/) do |arg1|
  arch = 'x86_64'
  $command_output = sshcmd("mgr-bootstrap --activation-keys=1-SUSE-PKG-#{arch} #{arg1}")[:stdout]
end

When(/^I fetch "([^"]*)" to "([^"]*)"$/) do |file, host|
  node = get_target(host)
  node.run("wget http://#{$server.ip}/#{file}")
end

When(/^I wait until file "([^"]*)" contains "([^"]*)" on server$/) do |file, content|
  repeat_until_timeout(message: "#{content} not found in file #{file}", report_result: true) do
    output = sshcmd("grep #{content} #{file}", ignore_err: true)
    break if output[:stdout] =~ /#{content}/
    sleep 2
    "\n-----\n#{output[:stderr]}\n-----\n"
  end
end

Then(/^the tomcat logs should not contain errors$/) do
  output = $server.run('cat /var/log/tomcat/*')
  msgs = %w[ERROR NullPointer]
  msgs.each do |msg|
    raise "-#{msg}-  msg found on tomcat logs" if output.include? msg
  end
end

When(/^I restart the spacewalk service$/) do
  $server.run('spacewalk-service restart')
end

When(/^I shutdown the spacewalk service$/) do
  $server.run('spacewalk-service stop')
end

When(/^I execute spacewalk-debug on the server$/) do
  $server.run('spacewalk-debug')
  code = file_extract($server, "/tmp/spacewalk-debug.tar.bz2", "spacewalk-debug.tar.bz2")
  raise "Download debug file failed" unless code.zero?
end

Then(/^I get logfiles from "([^"]*)"$/) do |target|
  node = get_target(target)
  os_version, os_family = get_os_version(node)
  if os_family =~ /^opensuse/
    node.run('zypper mr --enable os_pool_repo os_update_repo && zypper --non-interactive install tar')
  end
  node.run("journalctl > /var/log/messages && (tar cfvJP /tmp/#{target}-logs.tar.xz /var/log/ || [[ $? -eq 1 ]])")
  `mkdir logs` unless Dir.exist?('logs')
  code = file_extract(node, "/tmp/#{target}-logs.tar.xz", "logs/#{target}-logs.tar.xz")
  raise "Download log archive failed" unless code.zero?
end

Then(/^the susemanager repo file should exist on the "([^"]*)"$/) do |host|
  step %(file "/etc/zypp/repos.d/susemanager\:channels.repo" should exist on "#{host}")
end

Then(/^I should see "([^"]*)", "([^"]*)" and "([^"]*)" in the repo file on the "([^"]*)"$/) do |protocol, hostname, port, target|
  node = get_target(target)
  hostname = hostname == "proxy" ? $proxy.full_hostname : hostname
  base_url, _code = node.run('grep "baseurl" /etc/zypp/repos.d/susemanager\:channels.repo')
  base_url = base_url.strip.split('=')[1].delete '"'
  uri = URI.parse(base_url)
  puts 'Protocol: ' + uri.scheme + '  Host: ' + uri.host + '  Port: ' + uri.port.to_s
  parameters_matches = (uri.scheme == protocol && uri.host == hostname && uri.port == port.to_i)
  if !parameters_matches
    raise 'Some parameters are not as expected'
  end
end

When(/^I copy "([^"]*)" to "([^"]*)"$/) do |file, host|
  node = get_target(host)
  return_code = file_inject(node, file, File.basename(file))
  raise 'File injection failed' unless return_code.zero?
end

Then(/^the PXE default profile should be enabled$/) do
  step %(I wait until file "/srv/tftpboot/pxelinux.cfg/default" contains "ONTIMEOUT pxe-default-profile" on server)
end

Then(/^the PXE default profile should be disabled$/) do
  step %(I wait until file "/srv/tftpboot/pxelinux.cfg/default" contains "ONTIMEOUT local" on server)
end

When(/^I restart the network on the PXE boot minion$/) do
  # We have no IPv4 address on that machine yet,
  # so the only way to contact it is via IPv6 link-local.
  # We convert MAC address to IPv6 link-local address:
  mac = $pxeboot_mac.tr(':', '')
  hex = ((mac[0..5] + 'fffe' + mac[6..11]).to_i(16) ^ 0x0200000000000000).to_s(16)
  ipv6 = 'fe80::' + hex[0..3] + ':' + hex[4..7] + ':' + hex[8..11] + ':' + hex[12..15] + "%eth1"
  file = 'restart-network-pxeboot.exp'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($proxy, source, dest)
  raise 'File injection failed' unless return_code.zero?
  # We have no direct access to the PXE boot minion
  # so we run the command from the proxy
  $proxy.run("expect -f /tmp/#{file} #{ipv6}")
end

When(/^I reboot the PXE boot minion$/) do
  # we might have no or any IPv4 address on that machine
  # convert MAC address to IPv6 link-local address
  mac = $pxeboot_mac.tr(':', '')
  hex = ((mac[0..5] + 'fffe' + mac[6..11]).to_i(16) ^ 0x0200000000000000).to_s(16)
  ipv6 = 'fe80::' + hex[0..3] + ':' + hex[4..7] + ':' + hex[8..11] + ':' + hex[12..15] + "%eth1"
  STDOUT.puts "Rebooting #{ipv6}..."
  file = 'reboot-pxeboot.exp'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($proxy, source, dest)
  raise 'File injection failed' unless return_code.zero?
  $proxy.run("expect -f /tmp/#{file} #{ipv6}")
end

When(/^I stop and disable avahi on the PXE boot minion$/) do
  # we might have no or any IPv4 address on that machine
  # convert MAC address to IPv6 link-local address
  mac = $pxeboot_mac.tr(':', '')
  hex = ((mac[0..5] + 'fffe' + mac[6..11]).to_i(16) ^ 0x0200000000000000).to_s(16)
  ipv6 = 'fe80::' + hex[0..3] + ':' + hex[4..7] + ':' + hex[8..11] + ':' + hex[12..15] + "%eth1"
  STDOUT.puts "Stoppping and disabling avahi on #{ipv6}..."
  file = 'stop-avahi-pxeboot.exp'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($proxy, source, dest)
  raise 'File injection failed' unless return_code.zero?
  $proxy.run("expect -f /tmp/#{file} #{ipv6}")
end

When(/^I stop salt-minion on the PXE boot minion$/) do
  file = 'cleanup-pxeboot.exp'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($proxy, source, dest)
  raise 'File injection failed' unless return_code.zero?
  ipv4 = net_prefix + ADDRESSES['pxeboot']
  $proxy.run("expect -f /tmp/#{file} #{ipv4}")
end

When(/^I install the GPG key of the test packages repository on the PXE boot minion$/) do
  file = 'uyuni.key'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/tmp/" + file
  return_code = file_inject($server, source, dest)
  raise 'File injection failed' unless return_code.zero?
  system_name = get_system_name('pxeboot_minion')
  $server.run("salt-cp #{system_name} #{dest} #{dest}")
  $server.run("salt #{system_name} cmd.run 'rpmkeys --import #{dest}'")
end

When(/^the server starts mocking an IPMI host$/) do
  ["ipmisim1.emu", "lan.conf", "fake_ipmi_host.sh"].each do |file|
    source = File.dirname(__FILE__) + '/../upload_files/' + file
    dest = "/etc/ipmi/" + file
    return_code = file_inject($server, source, dest)
    raise 'File injection failed' unless return_code.zero?
  end
  $server.run("chmod +x /etc/ipmi/fake_ipmi_host.sh")
  $server.run("ipmi_sim -n < /dev/null > /dev/null &")
end

When(/^the server stops mocking an IPMI host$/) do
  $server.run("kill $(pidof ipmi_sim)")
  $server.run("kill $(pidof -x fake_ipmi_host.sh)")
end

When(/^I install a user-defined state for "([^"]*)" on the server$/) do |host|
  system_name = get_system_name(host)
  # copy state file to server
  file = 'user_defined_state.sls'
  source = File.dirname(__FILE__) + '/../upload_files/' + file
  dest = "/srv/salt/" + file
  return_code = file_inject($server, source, dest)
  raise 'File injection failed' unless return_code.zero?
  # generate top file and copy it to server
  script = "base:\n" \
           "  '#{system_name}':\n" \
           "    - user_defined_state\n"
  path = generate_temp_file('top.sls', script)
  return_code = file_inject($server, path, '/srv/salt/top.sls')
  raise 'File injection failed' unless return_code.zero?
  `rm #{path}`
  # make both files readeable by salt
  $server.run('chgrp salt /srv/salt/*')
end

When(/^I uninstall the user-defined state from the server$/) do
  $server.run('rm /srv/salt/{user_defined_state.sls,top.sls}')
end

When(/^I uninstall the managed file from "([^"]*)"$/) do |host|
  node = get_target(host)
  node.run('rm /tmp/test_user_defined_state')
end

Then(/^the cobbler report contains "([^"]*)" for system "([^"]*)"$/) do |arg1, system|
  output = sshcmd("cobbler system report --name #{system}:1", ignore_err: true)[:stdout]
  raise "Not found: #{output}" unless output.include?(arg1)
end

Then(/^the cobbler report contains "([^"]*)"$/) do |arg1|
  step %(the cobbler report contains "#{arg1}" for system "#{$client.full_hostname}")
end

Then(/^I clean the search index on the server$/) do
  output = sshcmd('/usr/sbin/rcrhn-search cleanindex', ignore_err: true)
  raise 'The output includes an error log' if output[:stdout].include?('ERROR')
end

When(/^I execute spacewalk\-channel and pass "([^"]*)"$/) do |arg1|
  command = "spacewalk-channel #{arg1}"
  $command_output, _code = $client.run(command)
end

When(/^spacewalk\-channel fails with "([^"]*)"$/) do |arg1|
  command = "spacewalk-channel #{arg1}"
  # we are checking that the cmd should fail here
  $command_output, code = $client.run(command, false)
  raise "#{command} should fail, but hasn't" if code.zero?
end

Then(/^I should get "([^"]*)"$/) do |arg1|
  raise "'#{arg1}' not found in output '#{$command_output}'" unless $command_output.include? arg1
end

Then(/^I shouldn't get "([^"]*)"$/) do |arg1|
  raise "'#{arg1}' found in output '#{$command_output}'" unless not $command_output.include? arg1
end

Then(/^I wait until mgr-sync refresh is finished$/) do
  # mgr-sync refresh is a slow operation, we don't use the default timeout
  cmd = "spacecmd -u admin -p admin api sync.content.listProducts"
  repeat_until_timeout(timeout: 900, message: "'mgr-sync refresh' did not finish") do
    result, code = $server.run(cmd, false)
    break if result.include? "SLES"
    sleep 5
  end
end

Then(/^I should see "(.*?)" in the output$/) do |arg1|
  raise "Command Output #{@command_output} don't include #{arg1}" unless @command_output.include? arg1
end

Then(/^service "([^"]*)" is enabled on "([^"]*)"$/) do |service, host|
  node = get_target(host)
  output, _code = node.run("systemctl is-enabled '#{service}'", false)
  output = output.split(/\n+/)[-1]
  raise "Service #{service} not enabled" if output != 'enabled'
end

Then(/^service "([^"]*)" is active on "([^"]*)"$/) do |service, host|
  node = get_target(host)
  output, _code = node.run("systemctl is-active '#{service}'", false)
  output = output.split(/\n+/)[-1]
  raise "Service #{service} not active" if output != 'active'
end

Then(/^service or socket "([^"]*)" is enabled on "([^"]*)"$/) do |name, host|
  node = get_target(host)
  output_service, _code_service = node.run("systemctl is-enabled '#{name}'", false)
  output_service = output_service.split(/\n+/)[-1]
  output_socket, _code_socket = node.run(" systemctl is-enabled '#{name}.socket'", false)
  output_socket = output_socket.split(/\n+/)[-1]
  raise if output_service != 'enabled' and output_socket != 'enabled'
end

Then(/^service or socket "([^"]*)" is active on "([^"]*)"$/) do |name, host|
  node = get_target(host)
  output_service, _code_service = node.run("systemctl is-active '#{name}'", false)
  output_service = output_service.split(/\n+/)[-1]
  output_socket, _code_socket = node.run(" systemctl is-active '#{name}.socket'", false)
  output_socket = output_socket.split(/\n+/)[-1]
  raise if output_service != 'active' and output_socket != 'active'
end

Then(/^socket "([^"]*)" is enabled on "([^"]*)"$/) do |service, host|
  node = get_target(host)
  output, _code = node.run("systemctl is-enabled '#{service}.socket'", false)
  output = output.split(/\n+/)[-1]
  raise "Service #{service} not enabled" if output != 'enabled'
end

Then(/^socket "([^"]*)" is active on "([^"]*)"$/) do |service, host|
  node = get_target(host)
  output, _code = node.run("systemctl is-active '#{service}.socket'", false)
  output = output.split(/\n+/)[-1]
  raise "Service #{service} not active" if output != 'active'
end

When(/^I run "([^"]*)" on "([^"]*)"$/) do |cmd, host|
  node = get_target(host)
  node.run(cmd)
end

When(/^I run "([^"]*)" on "([^"]*)" with logging$/) do |cmd, host|
  node = get_target(host)
  output, _code = node.run(cmd)
  puts "OUT: #{output}"
end

When(/^I run "([^"]*)" on "([^"]*)" without error control$/) do |cmd, host|
  node = get_target(host)
  _out, $fail_code = node.run(cmd, false)
end

Then(/^the command should fail$/) do
  raise 'Previous command must fail, but has NOT failed!' if $fail_code.zero?
end

When(/^I wait until file "([^"]*)" exists on "([^"]*)"$/) do |file, host|
  step %(I wait at most #{DEFAULT_TIMEOUT} seconds until file "#{file}" exists on "#{host}")
end

When(/^I wait at most (\d+) seconds until file "([^"]*)" exists on "([^"]*)"$/) do |seconds, file, host|
  node = get_target(host)
  repeat_until_timeout(timeout: seconds.to_i) do
    break if file_exists?(node, file)
    sleep(1)
  end
end

When(/^I wait until file "(.*)" exists on server$/) do |file|
  repeat_until_timeout do
    break if file_exists?($server, file)
    sleep(1)
  end
end

Then(/^I wait and check that "([^"]*)" has rebooted$/) do |host|
  reboot_timeout = 800
  system_name = get_system_name(host)
  check_shutdown(system_name, reboot_timeout)
  check_restart(system_name, get_target(host), reboot_timeout)
end

When(/^I call spacewalk\-repo\-sync for channel "(.*?)" with a custom url "(.*?)"$/) do |arg1, arg2|
  @command_output = sshcmd("spacewalk-repo-sync -c #{arg1} -u #{arg2}")[:stdout]
end

When(/^I disable IPv6 forwarding on all interfaces of the SLE minion$/) do
  $minion.run('sysctl net.ipv6.conf.all.forwarding=0')
end

When(/^I enable IPv6 forwarding on all interfaces of the SLE minion$/) do
  $minion.run('sysctl net.ipv6.conf.all.forwarding=1')
end

When(/^I wait for the openSCAP audit to finish$/) do
  host = $server.full_hostname
  @sle_id = retrieve_server_id($minion.full_hostname)
  @cli = XMLRPC::Client.new2('http://' + host + '/rpc/api')
  @sid = @cli.call('auth.login', 'admin', 'admin')
  begin
    repeat_until_timeout(message: "process did not complete") do
      scans = @cli.call('system.scap.list_xccdf_scans', @sid, @sle_id)
      # in the openscap test, we schedule 2 scans
      break if scans.length > 1
    end
  ensure
    @cli.call('auth.logout', @sid)
  end
end

And(/I check status "([^"]*)" with spacecmd on "([^"]*)"$/) do |status, host|
  system_name = get_system_name(host)
  cmd = "spacecmd -u admin -p admin system_listevents #{system_name} | head -n5"
  $server.run("spacecmd -u admin -p admin clear_caches")
  out, _code = $server.run(cmd)
  raise "#{out} should contain #{status}" unless out.include? status
end

When(/^I register this client for SSH push via tunnel$/) do
  # create backups of /etc/hosts and up2date config
  $server.run('cp /etc/hosts /etc/hosts.BACKUP')
  $server.run('cp /etc/sysconfig/rhn/up2date /etc/sysconfig/rhn/up2date.BACKUP')
  # generate expect file
  bootstrap = '/srv/www/htdocs/pub/bootstrap/bootstrap-ssh-push-tunnel.sh'
  script = "spawn spacewalk-ssh-push-init --client #{$client.ip} --register #{bootstrap} --tunnel\n" \
           "while {1} {\n" \
           "  expect {\n" \
           "    eof                                                        {break}\n" \
	   "    -re \"Are you sure you want to continue connecting.*\" {send \"yes\r\"}\n" \
           "    \"Password:\"                                              {send \"linux\r\"}\n" \
           "  }\n" \
           "}\n"
  path = generate_temp_file('push-registration.exp', script)
  step 'I copy "' + path + '" to "server"'
  `rm #{path}`
  # perform the registration
  filename = File.basename(path)
  bootstrap_timeout = 600
  $server.run("expect #{filename}", true, bootstrap_timeout, 'root')
  # restore files from backups
  $server.run('mv /etc/hosts.BACKUP /etc/hosts')
  $server.run('mv /etc/sysconfig/rhn/up2date.BACKUP /etc/sysconfig/rhn/up2date')
end

# Repositories and packages management
When(/^I enable repository "([^"]*)" on this "([^"]*)"((?: without error control)?)$/) do |repo, host, error_control|
  node = get_target(host)
  cmd = if host.include? 'ceos'
    "sed -i 's/enabled=.*/enabled=1/g' /etc/yum.repos.d/#{repo}.repo"
        elsif host.include? 'ubuntu'
    "sed -i '/^#\\s*deb.*/ s/^#\\s*deb /deb /' /etc/apt/sources.list.d/#{repo}.list"
        else
    "zypper mr --enable #{repo}"
        end
  node.run(cmd, error_control.empty?)
end

When(/^I disable repository "([^"]*)" on this "([^"]*)"((?: without error control)?)$/) do |repo, host, error_control|
  node = get_target(host)
  cmd = if host.include? 'ceos'
    "test -f /etc/yum.repos.d/#{repo}.repo && sed -i 's/enabled=.*/enabled=0/g' /etc/yum.repos.d/#{repo}.repo"
        elsif host.include? 'ubuntu'
    "sed -i '/^deb.*/ s/^deb /#deb /' /etc/apt/sources.list.d/#{repo}.list"
        else
    "zypper mr --disable #{repo}"
        end
  node.run(cmd, error_control.empty?)
end

When(/^I install pattern "([^"]*)" on this "([^"]*)"$/) do |pattern, host|
  node = get_target(host)
  raise 'Not found: zypper' unless file_exists?(node, '/usr/bin/zypper')
  cmd = "zypper --non-interactive install -t pattern #{pattern}"
  node.run(cmd, true)
end

When(/^I remove pattern "([^"]*)" from this "([^"]*)"$/) do |pattern, host|
  node = get_target(host)
  raise 'Not found: zypper' unless file_exists?(node, '/usr/bin/zypper')
  cmd = "zypper --non-interactive remove -t pattern #{pattern}"
  node.run(cmd, true)
end

When(/^I install package "([^"]*)" on this "([^"]*)"((?: without error control)?)$/) do |package, host, error_control|
  node = get_target(host)
  cmd = if host.include? 'ceos'
    "yum -y install #{package}"
        elsif host.include? 'ubuntu'
    "apt-get --assume-yes install #{package}"
        else
    "zypper --non-interactive install -y #{package}"
        end
  node.run(cmd, error_control.empty?)
end

When(/^I install old package "([^"]*)" on this "([^"]*)"((?: without error control)?)$/) do |package, host, error_control|
  node = get_target(host)
  cmd = if host.include? 'ceos'
    "yum -y downgrade #{package}"
        elsif host.include? 'ubuntu'
    "apt-get --assume-yes install #{package} --allow-downgrades"
        else
    "zypper --non-interactive install --oldpackage -y #{package}"
        end
  node.run(cmd, error_control.empty?)
end

When(/^I remove package "([^"]*)" from this "([^"]*)"((?: without error control)?)$/) do |package, host, error_control|
  node = get_target(host)
  cmd = if host.include? 'ceos'
    "yum -y remove #{package}"
        elsif host.include? 'ubuntu'
    "dpkg --remove #{package}"
        else
    "zypper --non-interactive remove -y #{package}"
        end
  node.run(cmd, error_control.empty?)
end

When(/^I wait until the package "(.*?)" has been cached on this "(.*?)"$/) do |pkg_name, host|
  node = get_target(host)
  cmd = "ls /var/cache/zypp/packages/susemanager:test-channel-x86_64/getPackage/*/*/#{pkg_name}*.rpm"
  repeat_until_timeout(message: "Package #{pkg_name} was not cached") do
    result, return_code = node.run(cmd, false)
    break if return_code.zero?
    sleep 2
  end
end

When(/^I create the "([^"]*)" bootstrap repository for "([^"]*)" on the server$/) do |arch, host|
  node = get_target(host)
  os_version, _os_family = get_os_version(node)
  cmd = 'false'
  if (os_version.include? '12') || (os_version.include? '15')
    cmd = "mgr-create-bootstrap-repo -c SLE-#{os_version}-#{arch}"
  elsif os_version.include? '11'
    sle11 = "#{os_version[0, 2]}-SP#{os_version[-1]}"
    cmd = "mgr-create-bootstrap-repo -c SLE-#{sle11}-#{arch}"
  end
  puts 'Creating the boostrap repository on the server: ' + cmd
  $server.run(cmd, false)
end

When(/^I open avahi port on the proxy$/) do
  sed = 's/FW_DEV_EXT=""/FW_DEV_EXT="eth0"/'
  $proxy.run("sed -i '#{sed}' /etc/sysconfig/SuSEfirewall2")
  sed = 's/FW_CONFIGURATIONS_EXT=""/FW_CONFIGURATIONS_EXT="avahi"/'
  $proxy.run("sed -i '#{sed}' /etc/sysconfig/SuSEfirewall2")
end

When(/^I copy server\'s keys to the proxy$/) do
  ['RHN-ORG-PRIVATE-SSL-KEY', 'RHN-ORG-TRUSTED-SSL-CERT', 'rhn-ca-openssl.cnf'].each do |file|
    return_code = file_extract($server, '/root/ssl-build/' + file, '/tmp/' + file)
    raise 'File extraction failed' unless return_code.zero?
    $proxy.run('mkdir -p /root/ssl-build')
    return_code = file_inject($proxy, '/tmp/' + file, '/root/ssl-build/' + file)
    raise 'File injection failed' unless return_code.zero?
  end
end

# rubocop:disable Metrics/BlockLength
When(/^I set up the private network on the terminals$/) do
  proxy = net_prefix + ADDRESSES['proxy']
  # /etc/sysconfig/network/ifcfg-eth1 and /etc/resolv.conf
  nodes = [$client, $minion]
  conf = "STARTMODE='auto'\\nBOOTPROTO='dhcp'"
  file = "/etc/sysconfig/network/ifcfg-eth1"
  script2 = "-e '/^#/d' -e 's/^search /search example.org /' -e '$anameserver #{proxy}' -e '/^nameserver /d'"
  file2 = "/etc/resolv.conf"
  nodes.each do |node|
    next if node.nil?
    node.run("echo -e \"#{conf}\" > #{file} && sed -i #{script2} #{file2} && ifup eth1")
  end
  # /etc/sysconfig/network-scripts/ifcfg-eth1 and /etc/sysconfig/network
  nodes = [$ceos_minion]
  file = "/etc/sysconfig/network-scripts/ifcfg-eth1"
  conf2 = "GATEWAYDEV=eth0"
  file2 = "/etc/sysconfig/network"
  nodes.each do |node|
    next if node.nil?
    domain, _code = node.run("grep '^search' /etc/resolv.conf | sed 's/^search//'")
    conf = "DOMAIN='#{domain.strip}'\\nDEVICE='eth1'\\nSTARTMODE='auto'\\nBOOTPROTO='dhcp'\\nDNS1='#{proxy}'"
    node.run("echo -e \"#{conf}\" > #{file} && echo -e \"#{conf2}\" > #{file2} && systemctl restart network")
  end
  # /etc/netplan/01-netcfg.yaml
  nodes = [$ubuntu_minion]
  source = File.dirname(__FILE__) + '/../upload_files/01-netcfg.yaml'
  dest = "/etc/netplan/01-netcfg.yaml"
  nodes.each do |node|
    next if node.nil?
    return_code = file_inject(node, source, dest)
    raise 'File injection failed' unless return_code.zero?
    node.run('netplan apply')
  end
  # PXE boot minion
  if $pxeboot_mac
    step %(I restart the network on the PXE boot minion)
  end
end
# rubocop:enable Metrics/BlockLength

Then(/^terminal "([^"]*)" should have got a retail network IP address$/) do |host|
  node = get_target(host)
  output, return_code = node.run("ip -4 address show eth1")
  raise "Terminal #{host} did not get an address on eth1: #{output}" unless return_code.zero? and output.include? net_prefix
end

Then(/^name resolution should work on terminal "([^"]*)"$/) do |host|
  node = get_target(host)
  # we need "host" utility
  step "I install package \"bind-utils\" on this \"#{host}\""
  # direct name resolution
  ["proxy.example.org", "dns.google.com"].each do |dest|
    output, return_code = node.run("host #{dest}", fatal = false)
    raise "Direct name resolution of #{dest} on terminal #{host} doesn't work: #{output}" unless return_code.zero?
    STDOUT.puts "#{output}"
  end
  # reverse name resolution
  net_prefix = $private_net.sub(%r{\.0+/24$}, ".")
  client = net_prefix + "2"
  [client, "8.8.8.8"].each do |dest|
    output, return_code = node.run("host #{dest}", fatal = false)
    raise "Reverse name resolution of #{dest} on terminal #{host} doesn't work: #{output}" unless return_code.zero?
    STDOUT.puts "#{output}"
  end
end

When(/^I configure the proxy$/) do
  # prepare the settings file
  settings = "RHN_PARENT=#{$server.ip}\n" \
             "HTTP_PROXY=''\n" \
             "VERSION=''\n" \
             "TRACEBACK_EMAIL=galaxy-noise@suse.de\n" \
             "USE_SSL=y\n" \
             "USE_EXISTING_CERTS=n\n" \
             "INSTALL_MONITORING=n\n" \
             "SSL_PASSWORD=spacewalk\n" \
             "SSL_ORG=SUSE\n" \
             "SSL_ORGUNIT=SUSE\n" \
             "SSL_COMMON=#{$proxy.ip}\n" \
             "SSL_CITY=Nuremberg\n" \
             "SSL_STATE=Bayern\n" \
             "SSL_COUNTRY=DE\n" \
             "SSL_EMAIL=galaxy-noise@suse.de\n" \
             "SSL_CNAME_ASK=''\n" \
             "POPULATE_CONFIG_CHANNEL=y\n" \
             "RHN_USER=admin\n" \
             "ACTIVATE_SLP=y\n"
  path = generate_temp_file('config-answers.txt', settings)
  step 'I copy "' + path + '" to "proxy"'
  `rm #{path}`
  # perform the configuration
  filename = File.basename(path)
  cmd = "configure-proxy.sh --non-interactive --rhn-user=admin --rhn-password=admin --answer-file=#{filename}"
  proxy_timeout = 600
  $proxy.run(cmd, true, proxy_timeout, 'root')
end

Then(/^The metadata buildtime from package "(.*?)" match the one in the rpm on "(.*?)"$/) do |pkg, host|
  # for testing buildtime of generated metadata - See bsc#1078056
  node = get_target(host)
  cmd = "dumpsolv /var/cache/zypp/solv/spacewalk\:test-channel-x86_64/solv | grep -E 'solvable:name|solvable:buildtime'| grep -A1 '#{pkg}$'| perl -ne 'if($_ =~ /^solvable:buildtime:\\s*(\\d+)/) { print $1; }'"
  metadata_buildtime, return_code = node.run(cmd)
  raise "Command failed: #{cmd}" unless return_code.zero?
  cmd = "rpm -q --qf '%{BUILDTIME}' #{pkg}"
  rpm_buildtime, return_code = node.run(cmd)
  raise "Command failed: #{cmd}" unless return_code.zero?
  raise "Wrong buildtime in metadata: #{metadata_buildtime} != #{rpm_buildtime}" unless metadata_buildtime == rpm_buildtime
end

When(/^I create channel "([^"]*)" from spacecmd of type "([^"]*)"$/) do |name, type|
  command = "spacecmd -u admin -p admin -- configchannel_create -n #{name} -t  #{type}"
  $server.run(command)
end

When(/^I update init.sls from spacecmd with content "([^"]*)" for channel "([^"]*)"$/) do |content, label|
  filepath = "/tmp/#{label}"
  $server.run("echo -e \"#{content}\" > #{filepath}", true, 600, 'root')
  command = "spacecmd -u admin -p admin -- configchannel_updateinitsls -c #{label} -f  #{filepath} -y"
  $server.run(command)
  file_delete($server, filepath)
end

When(/^I schedule apply configchannels for "([^"]*)"$/) do |host|
  system_name = get_system_name(host)
  $server.run('spacecmd -u admin -p admin clear_caches')
  command = "spacecmd -y -u admin -p admin -- system_scheduleapplyconfigchannels  #{system_name}"
  $server.run(command)
end

When(/^I create "([^"]*)" virtual machine on "([^"]*)"$/) do |vm_name, host|
  node = get_target(host)
  disk_path = "/tmp/#{vm_name}-disk.qcow2"

  # Create the throwable overlay image
  raise 'not found: qemu-img or /var/testsuite-data/disk-image-template.qcow2' unless file_exists?(node, '/usr/bin/qemu-img') and file_exists?(node, '/var/testsuite-data/disk-image-template.qcow2')
  node.run("qemu-img create -f qcow2 -b /var/testsuite-data/disk-image-template.qcow2 #{disk_path}")

  # Change the VM hostname
  node.run("mount_path=$(mktemp -d); guestmount -m /dev/sda1 -a #{disk_path} ${mount_path}; echo '#{node.hostname}-#{vm_name}.suse' >${mount_path}/etc/hostname; umount ${mount_path}; rmdir ${mount_path}")

  # Actually define the VM, but don't start it
  raise 'not found: virt-install' unless file_exists?(node, '/usr/bin/virt-install')
  node.run("virt-install --name #{vm_name} --memory 512 --vcpus 1 --disk path=#{disk_path} "\
           "--network network=default "\
           "--import --hvm --noautoconsole --noreboot")
end

Then(/^I should see "([^"]*)" virtual machine (shut off|running|paused) on "([^"]*)"$/) do |vm, state, host|
  node = get_target(host)
  repeat_until_timeout(message: "#{vm} virtual machine on #{host} never reached state #{state}") do
    output, _code = node.run("virsh domstate #{vm}")
    break if output.strip == state
    sleep 3
  end
end

When(/^I wait until virtual machine "([^"]*)" on "([^"]*)" is started$/) do |vm, host|
  node = get_target(host)
  repeat_until_timeout(message: "#{vm} virtual machine on #{host} OS failed did not come up yet") do
    output, _code = node.run("ssh -o StrictHostKeyChecking=no #{node.hostname}-#{vm}.local ls", fatal = false)
    break if output.include? "Permission denied"
    sleep 1
  end
end

Then(/^I should not see a "([^"]*)" virtual machine on "([^"]*)"$/) do |vm, host|
  node = get_target(host)
  repeat_until_timeout(message: "#{vm} virtual machine on #{host} still exists") do
    _output, code = node.run("virsh dominfo #{vm}", fatal = false)
    break if code == 1
    sleep 3
  end
end

Then(/^"([^"]*)" virtual machine on "([^"]*)" should have ([0-9]*)MB memory and ([0-9]*) vcpus$/) do |vm, host, mem, vcpu|
  node = get_target(host)
  repeat_until_timeout(message: "#{vm} virtual machine on #{host} never got #{mem}MB memory and #{vcpu} vcpus") do
    output, _code = node.run("virsh dumpxml #{vm}")
    has_memory = output.include? "<memory unit='KiB'>#{Integer(mem) * 1024}</memory>"
    has_vcpus = output.include? ">#{vcpu}</vcpu>"
    break if has_memory and has_vcpus
    sleep 3
  end
end

When(/^I reduce virtpoller run interval on "([^"]*)"$/) do |host|
  node = get_target(host)
  source = File.dirname(__FILE__) + '/../upload_files/susemanager-virtpoller.conf'
  dest = "/etc/salt/minion.d/susemanager-virtpoller.conf"
  return_code = file_inject(node, source, dest)
  raise 'File injection failed' unless return_code.zero?
  node.run("systemctl restart salt-minion")
end

# WORKAROUND
# Work around issue https://github.com/SUSE/spacewalk/issues/10360
# Remove as soon as the issue is fixed
When(/^I let Kiwi build from external repositories$/) do
  $server.run("sed -i 's/--ignore-repos-used-for-build//' /usr/share/susemanager/salt/images/kiwi-image-build.sls")
end

When(/^I refresh packages list via spacecmd on "([^"]*)"$/) do |client|
  node = get_system_name(client)
  $server.run("spacecmd -u admin -p admin clear_caches")
  command = "spacecmd -u admin -p admin system_schedulepackagerefresh #{node}"
  $server.run(command)
end

Then(/^I wait until refresh package list on "(.*?)" is finished$/) do |client|
  round_minute = 60 # spacecmd uses timestamps with precision to minutes only
  long_wait_delay = 600
  current_time = Time.now.strftime('%Y%m%d%H%M')
  timeout_time = (Time.now + long_wait_delay + round_minute).strftime('%Y%m%d%H%M')
  node = get_system_name(client)
  $server.run("spacecmd -u admin -p admin clear_caches")
  cmd = "spacecmd -u admin -p admin schedule_listcompleted #{current_time} #{timeout_time} #{node} | grep 'Package List Refresh scheduled by admin' | head -1"
  repeat_until_timeout(timeout: long_wait_delay, message: "'refresh package list' did not finish") do
    result, code = $server.run(cmd, false)
    break if result.include? '1    0    0'
    raise 'refresh package list failed' if result.include? '0    1    0'
    sleep 1
  end
end

When(/^spacecmd should show packages "([^"]*)" installed on "([^"]*)"$/) do |packages, client|
  node = get_system_name(client)
  $server.run("spacecmd -u admin -p admin clear_caches")
  command = "spacecmd -u admin -p admin system_listinstalledpackages #{node}"
  result, code = $server.run(command, false)
  packages.split(' ').each do |package|
    pkg = package.strip
    raise "package #{pkg} is not installed" unless result.include? pkg
  end
end

When(/^I wait until package "([^"]*)" is installed on "([^"]*)" via spacecmd$/) do |pkg, client|
  node = get_system_name(client)
  $server.run("spacecmd -u admin -p admin clear_caches")
  command = "spacecmd -u admin -p admin system_listinstalledpackages #{node}"
  repeat_until_timeout(timeout: 600, message: "package #{pkg} is not installed yet") do
    result, code = $server.run(command, false)
    break if result.include? pkg
    sleep 1
  end
end

When(/^I wait until package "([^"]*)" is removed from "([^"]*)" via spacecmd$/) do |pkg, client|
  node = get_system_name(client)
  $server.run("spacecmd -u admin -p admin clear_caches")
  command = "spacecmd -u admin -p admin system_listinstalledpackages #{node}"
  repeat_until_timeout(timeout: 600, message: "package #{pkg} is still present") do
    result, code = $server.run(command, false)
    sleep 1
    break unless result.include? pkg
  end
end

When(/^I prepare the retail configuration file on server$/) do
  source = File.dirname(__FILE__) + '/../upload_files/massive-import-terminals.yml'
  dest = '/tmp/massive-import-terminals.yml'
  return_code = file_inject($server, source, dest)
  raise "File #{file} couldn't be copied to server" unless return_code.zero?

  sed_values = "s/<PROXY_HOSTNAME>/#{$proxy.full_hostname}/; "
  sed_values << "s/<NET_PREFIX>/#{net_prefix}/; "
  sed_values << "s/<PROXY>/#{ADDRESSES['proxy']}/; "
  sed_values << "s/<RANGE_BEGIN>/#{ADDRESSES['range begin']}/; "
  sed_values << "s/<RANGE_END>/#{ADDRESSES['range end']}/; "
  sed_values << "s/<PXEBOOT>/#{ADDRESSES['pxeboot']}/; "
  sed_values << "s/<PXEBOOT_MAC>/#{$pxeboot_mac}/; "
  sed_values << "s/<MINION>/#{ADDRESSES['minion']}/; "
  sed_values << "s/<MINION_MAC>/#{get_mac_address('sle_minion')}/; "
  sed_values << "s/<CLIENT>/#{ADDRESSES['client']}/; "
  sed_values << "s/<CLIENT_MAC>/#{get_mac_address('sle_client')}/; "
  sed_values << "s/<IMAGE>/#{compute_image_name}/"
  $server.run("sed -i '#{sed_values}' #{dest}")
end

When(/^I import the retail configuration using retail_yaml command$/) do
  filepath = '/tmp/massive-import-terminals.yml'
  $server.run("retail_yaml --api-user admin --api-pass admin --from-yaml #{filepath}")
end

When(/^I delete all the imported terminals$/) do
  terminals = read_terminals_from_yaml
  terminals.each do |terminal|
    next if (terminal.include? 'minion') || (terminal.include? 'client')
    puts "Deleting terminal with name: #{terminal}"
    steps %(
      When I follow "#{terminal}" terminal
      And I follow "Delete System"
      And I should see a "Confirm System Profile Deletion" text
      And I click on "Delete Profile"
      Then I should see a "has been deleted" text
    )
  end
end

When(/^I remove all the DHCP hosts created by retail_yaml$/) do
  terminals = read_terminals_from_yaml
  terminals.each do |terminal|
    raise unless find(:xpath, "//*[@value='#{terminal}']/../../../..//*[@title='Remove item']").click
  end
end

When(/^I remove the bind zones created by retail_yaml$/) do
  domain = read_branch_prefix_from_yaml
  raise unless find(:xpath, "//*[text()='Configured Zones']/../..//*[@value='#{domain}']/../../../..//*[@title='Remove item']").click
  raise unless find(:xpath, "//*[text()='Available Zones']/../..//*[@value='#{domain}' and @name='Name']/../../../..//i[@title='Remove item']").click
end
