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
require_relative "snapshot_dbus"

module Yast2
  module Snapper
    class Snapshot
      
      include Yast::Logger

      attr_accessor :number, :type, :pre_number, :timestamp, :user, :description, :cleanup_algo, :user_data, :number, :config, :strategy

      STRATEGIES = { :dbus => SnapshotDBus }
      TYPES = [:pre, :post, :single]

      def initialize(number, type, pre_number, timestamp, user, cleanup_algo, description, user_data, config = "root", strategy = SnapshotDBus)
        @number = number
        @type = type
        @pre_number = pre_number
        @timestamp = timestamp
        @user = user
        @cleanup_algo = cleanup_algo
        @description = description
        @user_data = user_data
        @strategy = strategy.new(self) 
        @config = config
      end

      
      def post(configs=nil, custom_strategy = Snapshot.default_strategy)
        Snapshot.all(config, custom_strategy).find {|s| s.pre_number == self.number }
      end

      def pre(configs=nil, custom_strategy = Snapshot.default_strategy)
        @previous ||= @pre_number ? Snapshot.find(self.pre_number, configs, custom_strategy) : nil
      end     

      alias_method :previous, :pre

      TYPES.map do |t|
        define_method "#{t}?" do
          type == t || type == t.upcase
        end
      end

      class << self
        def default_strategy
          STRATEGIES[:dbus]
        end

        def all(configs = nil, strategy = Snapshot.default_strategy)
          strategy.all(configs)
        end

        def find(number, configs = nil, strategy = Snapshot.default_strategy)
          strategy.all(configs).find {|s| s.number == number }
        end

        def create_single(config_name, description, cleanup, user_data = {}, strategy = Snapshot.default_strategy)
          num = strategy.create_single(config_name, description, cleanup, user_data)   
          num ? find(num, config_name) : nil
        end

        def create_pre(config_name, description, cleanup, user_data = {}, strategy = Snapshot.default_strategy)
          num = strategy.create_pre(config_name, description, cleanup, user_data)   
          num ? find(num, config_name) : nil
        end

        def create_post(config_name, pre_number, description, cleanup, user_data = {}, strategy = Snapshot.default_strategy)
          num = strategy.create_post(config_name, description, cleanup, user_data)
          num ? find(num, config_name) : nil
        end

      end
    end
  end
end
