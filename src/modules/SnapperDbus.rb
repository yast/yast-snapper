# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 Novell, Inc. All Rights Reserved.
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

      log.info("connecting to snapperd")

      @system_bus = DBus::SystemBus.instance()
      @service = @system_bus.service("org.opensuse.Snapper")
      @dbus_object = @service.object("/org/opensuse/Snapper")
      @dbus_object.default_iface = "org.opensuse.Snapper"
      @dbus_object.introspect()

    end


    def list_configs()

      log.info("list_configs")

      result = @dbus_object.ListConfigs().first()
      log.info("list_configs result:#{result}")

      ret = result.map { |x| x[0] }

      log.info("list_configs ret:#{ret}")

      return ret

    end


    def list_snapshots(config_name)

      log.info("list_snapshots config_name:#{config_name}")

      result = @dbus_object.ListSnapshots(config_name).first()
      log.info("list_snapshots result:#{result}")

      def type_from_int_to_symbol(i)
        return [ :SINGLE, :PRE, :POST ][i]
      end

      ret = result.map { |snapshot|
        { "num" => snapshot[0], "type" => type_from_int_to_symbol(snapshot[1]),
          "pre_num" => snapshot[2], "date" => Time.at(snapshot[3]), "uid" => snapshot[4],
          "description" => snapshot[5], "cleanup" => snapshot[6], "userdata" => snapshot[7] }
      }

      log.info("list_snapshots ret:#{ret}")

      return ret

    end


    def create_single_snapshot(config_name, description, cleanup, userdata)

      log.info("create_single_snapshot config_name:#{config_name} description:#{description} "\
               "cleanup:#{cleanup} userdata:#{userdata}")

      result = @dbus_object.CreateSingleSnapshot(config_name, description, cleanup, userdata).first()
      log.info("create_single_snapshot result:#{result}")

      ret = result

      log.info("create_single_snapshot ret:#{ret}")

      return ret

    end


    def create_pre_snapshot(config_name, description, cleanup, userdata)

      log.info("create_pre_snapshot config_name:#{config_name} description:#{description} "\
               "cleanup:#{cleanup} userdata:#{userdata}")

      result = @dbus_object.CreatePreSnapshot(config_name, description, cleanup, userdata).first()
      log.info("create_pre_snapshot result:#{result}")

      ret = result

      log.info("create_pre_snapshot ret:#{ret}")

      return ret

    end


    def create_post_snapshot(config_name, prenum, description, cleanup, userdata)

      log.info("create_post_snapshot config_name:#{config_name} prenum:#{prenum} "\
               "description:#{description} cleanup:#{cleanup} userdata:#{userdata}")

      result = @dbus_object.CreatePostSnapshot(config_name, prenum, description, cleanup,
                                               userdata).first()
      log.info("create_post_snapshot result:#{result}")

      ret = result

      log.info("create_post_snapshot ret:#{ret}")

      return ret

    end


    def delete_snapshots(config_name, nums)

      log.info("delete_snapshots config_name:#{config_name} nums:#{nums}")

      result = @dbus_object.DeleteSnapshots(config_name, nums)
      log.info("delete_snapshots result:#{result}")

      ret = result

      log.info("delete_snapshots ret:#{ret}")

      return ret

    end


    def set_snapshot(config_name, num, description, cleanup, userdata)

      log.info("set_snapshot config_name:#{config_name} num:#{num} "\
               "description:#{description} cleanup:#{cleanup} userdata:#{userdata}")

      result = @dbus_object.SetSnapshot(config_name, num, description, cleanup, userdata).first()
      log.info("set_snapshot result:#{result}")

      ret = result

      log.info("set_snapshot ret:#{ret}")

      return ret

    end


  end

  SnapperDbus = SnapperDbusClass.new
  SnapperDbus.main

end
