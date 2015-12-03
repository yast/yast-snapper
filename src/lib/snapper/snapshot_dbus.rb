require 'yast'
require 'dbus'

module Yast2
  module Snapper
    class SnapshotDBus
      
      include Yast::Logger

      TYPE_INT_TO_SYMBOL = {
        0 => :SINGLE,
        1 => :PRE,
        2 => :POST
      }
      def initialize(context)
        @context = context
      end

      class << self
        
        def all(configs)
          configs = list_configs if !configs
          snapshots = [configs].flatten.each_with_object([]) do |config, a|
            list_snapshots(config).each do |snapshot|
              next if snapshot[0] == 0
              s = {
                "num" => snapshot[0],
                "type" => TYPE_INT_TO_SYMBOL[snapshot[1]],
                "pre_num" => snapshot[2],
                "date" => Time.at(snapshot[3]),
                "uid" => snapshot[4],
                "description" => unescape(snapshot[5]),
                "cleanup" => unescape(snapshot[6]),
                "userdata" => unescape(snapshot[7])
              }
              a << Snapshot.new(s["num"], s["type"], s["pre_num"], s["date"],
                s["uid"], s["description"], s["cleanup"], s["userdata"], config, self) 
            end
          end
        end

        def create_single(config_name, description, cleanup, userdata)
          result = dbus_object.CreateSingleSnapshot(config_name, escape(description), escape(cleanup),
                                                     escape(userdata)).first
          log.debug("create_single_snapshot config_name:#{config_name} description:#{description} "\
                   "cleanup:#{cleanup} userdata:#{userdata} result:#{result}")
          result
        end


        def create_pre(config_name, description, cleanup, userdata)
          result = dbus_object.CreatePreSnapshot(config_name, escape(description), escape(cleanup),
                                                  escape(userdata)).first
          log.debug("create_pre_snapshot config_name:#{config_name} description:#{description} "\
                   "cleanup:#{cleanup} userdata:#{userdata} result: #{result}")

          result
        end


        def create_post(config_name, prenum, description, cleanup, userdata)
          result = dbus_object.CreatePostSnapshot(config_name, prenum, escape(description),
                                                   escape(cleanup), escape(userdata)).first
          log.debug("create_post_snapshot config_name:#{config_name} prenum:#{prenum} "\
                   "description:#{description} cleanup:#{cleanup} userdata:#{userdata}"\
                   "result #{result}")

          result
        end


        def delete(config_name, nums)
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

        def list_snapshots(config_name = nil)
          result = dbus_object.ListSnapshots(config_name).first
          log.debug("list_snapshots for name #{config_name} result:#{result}")
          result
        end

        def dbus_object
          @dbus_object ||= DBus::SystemBus.instance().
            service("org.opensuse.Snapper").
            object("/org/opensuse/Snapper")
          @dbus_object.default_iface = "org.opensuse.Snapper"
          @dbus_object.introspect()
          @dbus_object
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
    end
  end
end
