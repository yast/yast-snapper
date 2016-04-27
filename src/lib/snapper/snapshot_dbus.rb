# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

require "yast"
require "dbus"

module Yast
  class SnapshotDBus
    extend Forwardable
    include Yast::Logger

    SNAPSHOT_ID = {
      0 => "single",
      1 => "pre",
      2 => "post"
    }.freeze

    def_delegators :@context, :config, :number, :pre_number

    attr_accessor :context

    def initialize(snapshot = nil)
      @context = snapshot
    end

    def all(configs)
      configs ||= list_configs
      dbus_snapshots = Array(configs).each_with_object([]) do |config, snapshot_list|
        list_snapshots(config).each do |dbus_snapshot|
          next if dbus_snapshot[0] == 0
          snapshot_list << {
            type:         SNAPSHOT_ID[dbus_snapshot[1]],
            number:       dbus_snapshot[0],
            pre_number:   dbus_snapshot[2].to_i,
            timestamp:    Time.at(dbus_snapshot[3]),
            uid:          dbus_snapshot[4],
            description:  unescape(dbus_snapshot[5]),
            cleanup_algo: unescape(dbus_snapshot[6]),
            user_data:    unescape(dbus_snapshot[7]),
            config:       config
          }
        end
      end

      dbus_snapshots
    end

    def create
      attrs = [config || "", pre_number, description, cleanup, user_data]

      attrs.delete_at(1) if !@context.post?
      log.info "Creating snapshot #{@context.inspect} with result #{attrs.inspect}."

      result = SnapshotDBus.dbus_object.send("Create#{@context.name.capitalize}Snapshot", *attrs).first

      log.info "Creating snapshot #{@context.inspect} with result #{result}."

      result
    end

    def description
      escape(@context.description || "")
    end

    def cleanup
      escape(@context.cleanup || "")
    end

    def user_data
      escape(@context.user_data || {})
    end

    def update
      result = SnapshotDBus.dbus_object.SetSnapshot(config, number, description, cleanup, user_data).first

      log.info "Updating snapshot #{@context.inspect} with result #{result.inspect}."

      result
    end

    def delete
      result = SnapshotDBus.dbus_object.DeleteSnapshots(config, [number]).first
      log.debug("delete_snapshots config:#{config} nums:#{number} result:#{result}")

      result
    end

    def mount_point
      result = SnapshotDBus.dbus_object.GetMountPoint(config, number).first
      log.debug("Mount point for config_name:#{config} num:#{number} result#{result}")

      result
    end

    def list_configs
      result = SnapshotDBus.dbus_object.ListConfigs().first
      log.debug("list_configs result:#{result}")

      result.map(&:first)
    end

    def get_config(config_name)
      result = SnapshotDBus.dbus_object.GetConfig(config_name).first
      log.debug("get_config for name '#{config_name}' result:#{result}")

      result
    end

    def list_snapshots(config_name = nil)
      result = SnapshotDBus.dbus_object.ListSnapshots(config_name).first
      log.debug("list_snapshots for name #{config_name} result:#{result}")
      result
    end

    def get_modified_files(from, to)
      create_comparison(from.config, from, to)
      files = get_files(from.config, from, to)
      delete_comparison(from.config, from, to)
      files
    end

    def create_comparison(config, from, to)
      to_number = to ? to.number : 0
      result = SnapshotDBus.dbus_object.CreateComparison(config, from.number, to_number).first
      log.debug("create_comparison config_name:#{config} "\
                "num1:#{from.number} num2:#{to_number} result: #{result}")

      result
    end

    def delete_comparison(config, from, to)
      to_number = to ? to.number : 0
      result = SnapshotDBus.dbus_object.DeleteComparison(config, from.number, to_number).first
      log.debug("delete_comparison config_name:#{config} "\
                "num1:#{from.number} num2:#{to_number} result: #{result}")

      result
    end

    def get_files(config_name, from, to)
      to_number = to ? to.number : 0
      result = SnapshotDBus.dbus_object.GetFiles(config_name, from.number, to_number).first
      log.debug("get_files config_name:#{config_name} "\
                "num1:#{from.number} num2:#{to_number} result:#{result}")

      result.map do |file|
        { "filename" => unescape(file[0]), "status" => file[1] }
      end
    end

    class << self
      def dbus_object
        return @dbus_object if @dbus_object
        @dbus_object =
          DBus::SystemBus.instance
                         .service("org.opensuse.Snapper")
                         .object("/org/opensuse/Snapper")
        @dbus_object.default_iface = "org.opensuse.Snapper"
        @dbus_object.introspect
        @dbus_object
      end
    end

  private

    # Escape a String or Hash for snapperd.
    # See snapper dbus documentation for details.
    def escape(str)
      ret = str.dup

      case ret
      when ::String
        ret.force_encoding(Encoding::ASCII_8BIT)
        ret.gsub!(/(\\|[\x80-\xff])/n) do |tmp|
          if tmp == "\\"
            "\\\\"
          else
            "\\x" + tmp[0].ord.to_s(16)
          end
        end
      when Hash
        ret = ret.map { |k, v| [escape(k), escape(v)] }.to_h
      else
        raise "cannot escape object #{ret.class}"
      end

      ret
    end

    # Unescape a String or Hash from snapperd.
    # See snapper dbus documentation for details.
    def unescape(str)
      ret = str.dup

      case ret
      when ::String
        ret.force_encoding(Encoding::ASCII_8BIT)
        ret.gsub!(/\\(\\|x\h\h)/n) do |tmp|
          if tmp == "\\\\"
            "\\"
          else
            tmp[2, 2].hex.chr
          end
        end
      when Hash
        ret = ret.map { |k, v| [unescape(k), unescape(v)] }.to_h
      else
        raise "cannot unescape object #{ret.class}"
      end

      ret
    end
  end
end
