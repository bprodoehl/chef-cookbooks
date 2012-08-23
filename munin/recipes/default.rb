#
# Cookbook Name:: munin
# Recipe:: default
#
# Copyright 2012, Hiroaki Nakamura
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

version = node[:munin][:version]

# 'cron' or 'cgi' ('cgi' includes FastCGI)
generation_strategy = node[:munin][:generation_strategy] || 'cron'

group 'munin' do
  gid node[:munin][:gid]
end

user 'munin' do
  uid node[:munin][:uid]
  gid 'munin'
  shell '/sbin/nologin'
  comment 'Munin networked resource monitoring tool'
end

%w{ make gcc }.each do |pkg|
  package pkg
end

bash 'munin_install_perl_modules' do
  code <<-EOH
    cpanm Time::HiRes Storable Digest::MD5 HTML::Template Text::Balanced \
      Params::Validate Net::SSLeay Getopt::Long \
      File::Copy::Recursive CGI::Fast Log::Log4perl \
      Log::Dispatch Log::Dispatch::FileRotate MIME::Lite \
      Mail::Sendmail URI IO::Socket::INET6 FCGI
      # These modules were not found.
      # TimeDate IPC::Shareable Mail::Sender MailTools
  EOH
end

remote_file "/usr/local/src/munin-#{version}.tar.gz" do
  source "http://downloads.sourceforge.net/project/munin/stable/#{version}/munin-#{version}.tar.gz"
  case version
  when "2.0.4"
    checksum "309388e3528b41d727cea01233f0d4f60714e2de443576e1c472e8a1dc81722c"
  end
end

bash 'install_munin' do
  file_dir = "#{File.dirname(File.dirname(__FILE__))}/files/default"
  cwd '/usr/local/src/'
  code <<-EOH
    tar xf munin-#{version}.tar.gz &&
    cd munin-#{version} &&
    if [ ! -f Makefile.config.orig ]; then
      patch -b -p1 < #{file_dir}/Makefile.config.patch
    fi &&
    make &&
    make install &&
    if [ #{generation_strategy} = 'cgi' ]; then
      rm -rf /usr/local/munin/www/docs
    fi &&
    chmod 777 /var/log/munin /var/munin/cgi-tmp
  EOH
  not_if { FileTest.exists?("/usr/local/munin/lib/munin-asyncd") }
end
#    rm -rf /usr/local/munin/www/docs &&


if generation_strategy == 'cron'
  package 'cronie'

  cookbook_file "/etc/cron.d/munin" do
    source "munin.cron"
    owner 'root'
    group 'root'
    mode '0644'
    not_if { FileTest.exists?("/etc/cron.d/munin") }
  end

  service 'crond' do
    action [:enable, :start]
  end
end

bash 'create_munin-htpasswd' do
  code <<-EOH
    htpasswd -b -c /etc/munin/munin-htpasswd "#{node[:munin][:web_interface_login]}" "#{node[:munin][:web_interface_password]}" 
  EOH
  not_if { FileTest.exists?("/etc/munin/munin-htpasswd") }
end

template '/etc/munin/munin.conf' do
  source 'munin.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    :host_tree_configs => node[:munin][:host_tree_configs],
    :generation_strategy => generation_strategy
  )
end

cookbook_file '/etc/httpd/conf.d/munin.conf' do
  source (generation_strategy == 'cgi' ?
          'dynamic.apache.munin.conf' : 'static.apache.munin.conf')
  owner 'root'
  group 'root'
  mode '0644'
end
bash 'munin_apache_graceful_restart' do
  code <<-EOH
    service httpd graceful
  EOH
end

template '/etc/nginx/https.location.d/https.munin.conf' do
  source 'https.munin.conf.erb'
  variables(
    :backend_port => node[:apache][:port]
  )
end
service 'nginx' do
  supports :reload => true
  action [:reload]
end
