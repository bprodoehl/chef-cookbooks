#
# Cookbook Name:: pcre
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

version = node[:pcre][:version]

%w{ make gcc gcc-c++ }.each do |pkg|
  package pkg
end

remote_file "/usr/local/src/pcre-#{version}.tar.bz2" do
  source "http://downloads.sourceforge.net/project/pcre/pcre/#{version}/pcre-#{version}.tar.bz2"
  case version
  when "8.32"
    checksum "a913fb9bd058ef380a2d91847c3c23fcf98e92dc3b47cd08a53c021c5cde0f55"
  when "8.31"
    checksum "5778a02535473c7ee7838ea598c19f451e63cf5eec0bf0307a688301c9078c3c"
  when "8.30"
    checksum "c1113fd7db934e97ad8b3917d432e5b642e9eb9afd127eb797804937c965f4ac"
  end
end

bash 'install_pcre' do
  cwd '/usr/local/src/'
  code <<-EOH
    yum remove -y pcre-devel &&
    tar xf pcre-#{version}.tar.bz2 &&
    cd pcre-#{version} &&
    ./configure --prefix=/usr/local --libdir=/usr/local/lib64 \
      --enable-jit --enable-utf &&
    make &&
    make install &&
    echo /usr/local/lib64 > /etc/ld.so.conf.d/pcre-#{version}.x86_64.conf
    ldconfig
  EOH
  not_if { FileTest.exists?("/usr/local/lib64/libpcre.so.1") }
end
