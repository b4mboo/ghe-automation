#!/usr/bin/env ruby

# Launch new instance on AWS using Ansible.
instance = `ansible-playbook /home/ec2-user/scripts/ansible-ghe-launch.yaml --extra-vars 'image=ami-ecb96483 region=eu-central-1 key_name=ES-Jumphost'`
puts instance

# TODO: Check whether GHE is ready, instead of blindly waiting for a minute.
sleep 60

# Variables to configure the script.
hostname = instance[/.*public_ip': u'([^', u]*)/,1]
password = File.read('/home/ec2-user/secrets/ghe-password').chomp!
protocol = 'https://'
port = 8443
license = '/home/ec2-user/licenses/ghe-license.ghl'
keys = '/home/ec2-user/keys'
backup-utils = '/home/ec2-user/backup-utils-master'
snapshot = '2.7.3'

# Variables to reduce code duplication.
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
Dir.glob("#{keys}/*").select{|k| k.end_with?(".pub")}.each do |key|
  system "#{curl} '#{path}/settings/authorized-keys' -F authorized_key=@#{key}"
end

# Restore data from backup.
system "#{curl} '#{path}/maintenance' -d 'maintenance={\"enabled\":true, \"when\":\"now\"}'"
system "#{backup-utils}/bin/ghe-restore -v -f -s #{snapshot} #{hostname}"
system "#{curl} '#{path}/maintenance' -d 'maintenance={\"enabled\":false, \"when\":\"now\"}'"

# Done.
puts "GitHub Enterprise is ready at #{protocol}#{hostname}."
