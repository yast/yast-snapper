# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 SUSE LLC. All Rights Reserved.
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

  class SnapperDbusClass < Module

    include Yast::Logger

    def main
    end


    def list_configs
      result = dbus_object.ListConfigs().first
      log.debug("list_configs result:#{result}")

      result.map(&:first)
    end


    def get_config(config_name)
      result = dbus_object.GetConfig(config_name).first
      log.debug("get_config for name '#{config_name}' result:#{result}")

      result
    end


    TYPE_INT_TO_SYMBOL = {
      0 => :SINGLE,
      1 => :PRE,
      2 => :POST
    }

    def list_snapshots(config_name)
      result = dbus_object.ListSnapshots(config_name).first
      log.debug("list_snapshots for name #{config_name} result:#{result}")

      ret = result.map do |snapshot|
        {
          "num" => snapshot[0],
          "type" => TYPE_INT_TO_SYMBOL[snapshot[1]],
          "pre_num" => snapshot[2],
          "date" => Time.at(snapshot[3]),
          "uid" => snapshot[4],
          "description" => unescape(snapshot[5]),
          "cleanup" => unescape(snapshot[6]),
          "userdata" => unescape(snapshot[7])
        }
      end

      log.debug("list_snapshots ret:#{ret}")

      return ret

    end


    def create_single_snapshot(config_name, description, cleanup, userdata)
      result = dbus_object.CreateSingleSnapshot(config_name, escape(description), escape(cleanup),
                                                 escape(userdata)).first
      log.debug("create_single_snapshot config_name:#{config_name} description:#{description} "\
               "cleanup:#{cleanup} userdata:#{userdata} result:#{result}")

      result
    end


    def create_pre_snapshot(config_name, description, cleanup, userdata)
      result = dbus_object.CreatePreSnapshot(config_name, escape(description), escape(cleanup),
                                              escape(userdata)).first
      log.debug("create_pre_snapshot config_name:#{config_name} description:#{description} "\
               "cleanup:#{cleanup} userdata:#{userdata} result: #{result}")

      result
    end


    def create_post_snapshot(config_name, prenum, description, cleanup, userdata)
      result = dbus_object.CreatePostSnapshot(config_name, prenum, escape(description),
                                               escape(cleanup), escape(userdata)).first
      log.debug("create_post_snapshot config_name:#{config_name} prenum:#{prenum} "\
               "description:#{description} cleanup:#{cleanup} userdata:#{userdata}"\
               "result #{result}")

      result
    end


    def delete_snapshots(config_name, nums)
      result = dbus_object.DeleteSnapshots(config_name, nums).first
      log.debug("delete_snapshots config_name:#{config_name} nums:#{nums} result:#{result}")

      result
    end


    def set_snapshot(config_name, num, description, cleanup, userdata)
      result = dbus_object.SetSnapshot(config_name, num, escape(description), escape(cleanup),
                                        escape(userdata)).first
      log.debug("set_snapshot config_name:#{config_name} num:#{num} "\
               "description:#{description} cleanup:#{cleanup} userdata:#{userdata} "\
               "result #{result}")

      result
    end


    def get_mount_point(config_name, num)
      result = dbus_object.GetMountPoint(config_name, num).first
      log.debug("get_mount_point config_name:#{config_name} num:#{num} result#{result}")

      result
    end


    def create_comparison(config_name, num1, num2)
      result = dbus_object.CreateComparison(config_name, num1, num2).first
      log.debug("create_comparison config_name:#{config_name} num1:#{num1} num2:#{num2} "\
               "result: #{result}")

      result
    end


    def delete_comparison(config_name, num1, num2)
      result = dbus_object.DeleteComparison(config_name, num1, num2).first
      log.debug("delete_comparison config_name:#{config_name} num1:#{num1} num2:#{num2} "\
               "result:#{result}")

      result
    end


    def get_files(config_name, num1, num2)
      result = dbus_object.GetFiles(config_name, num1, num2).first
      log.debug("get_files config_name:#{config_name} num1:#{num1} num2:#{num2} result:#{result}")

      result.map do |file|
        { "filename" => unescape(file[0]), "status" => file[1] }
      end
    end


    private

    def dbus_object
      return @dbus_object if @dbus_object

      log.info("connecting to snapperd")

      @system_bus = DBus::SystemBus.instance()
      @service = @system_bus.service("org.opensuse.Snapper")
      @dbus_object = @service.object("/org/opensuse/Snapper")
      @dbus_object.default_iface = "org.opensuse.Snapper"
      @dbus_object.introspect()
      @dbus_object
    end

    # Escape a String or Hash for snapperd. See snapper dbus documentation for details.
    def escape(str)

      ret = str.dup

      if ret.is_a?(::String)

        ret.force_encoding(Encoding::ASCII_8BIT)
        ret.gsub!(/(\\|[\x80-\xff])/n) do |tmp|
          if tmp == "\\"
            "\\\\"
          else
            "\\x" + tmp[0].ord.to_s(16)
          end
        end

      elsif ret.is_a?(Hash)

        ret = ret.map { |k, v| [ escape(k), escape(v) ] }.to_h

      elsif

        raise RuntimeError, "cannot escape object"

      end

      return ret

    end


    # Unescape a String or Hash from snapperd. See snapper dbus documentation for details.
    def unescape(str)

      ret = str.dup

      if ret.is_a?(::String)

        ret.force_encoding(Encoding::ASCII_8BIT)
        ret.gsub!(/\\(\\|x\h\h)/n) do |tmp|
          if tmp == "\\\\"
            "\\"
          else
            tmp[2,2].hex.chr
          end
        end

      elsif ret.is_a?(Hash)

        ret = ret.map { |k, v| [ unescape(k), unescape(v) ] }.to_h

      elsif

        raise RuntimeError, "cannot unescape object"

      end

      return ret

    end

  end

  SnapperDbus = SnapperDbusClass.new
  SnapperDbus.main

end
