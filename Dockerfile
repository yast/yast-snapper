FROM registry.opensuse.org/yast/head/containers/yast-ruby:latest
RUN RUBY_VERSION=`rpm --eval '%{rb_default_ruby_abi}'` && \
  zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  "rubygem($RUBY_VERSION:ruby-dbus)"
COPY . /usr/src/app
