#!/usr/bin/env ruby

# Variables which may need to be configurable at some point.
hostname = ARGV[0]
password = ARGV[1] || File.read('/home/ec2-user/secrets/ghe-password').chomp!
protocol = 'https://'
port = 8443
license = '/home/ec2-user/licenses/ghe-license.ghl'

# Variables which are simply created to reduce code duplication.
curl = 'curl -L -k -X POST'
api = '/setup/api'
url = "#{hostname}:#{port}"
login = "api_key:#{password}"
path = "#{protocol}#{login}@#{url}#{api}"

# API calls to setup the new GitHub Enterprise instance.
system "#{curl} '#{protocol}#{url}#{api}/start' -F license=@#{license} -F 'password=#{password}'"
system "#{curl} '#{path}/configure'"
check = lambda { `curl -L -k '#{path}/configcheck'` }
status = ''
while status.scan(/DONE/).count != 5
  puts 'Waiting...'
  sleep 5
  status = check.call
  puts status
end
Dir.glob("/home/ec2-user/keys/*").select{|k| k.end_with?(".pub")}.each do |key|
  system "#{curl} '#{path}/settings/authorized-keys' -F authorized_key=@#{key}"
end

# Restore data from backup.
system "#{curl} '#{path}/maintenance' -d 'maintenance={\"enabled\":true, \"when\":\"now\"}'"
system "/home/ec2-user/backup-utils-master/bin/ghe-restore -v -f -s 2.7.3 #{hostname}"
system "#{curl} '#{path}/maintenance' -d 'maintenance={\"enabled\":false, \"when\":\"now\"}'"
