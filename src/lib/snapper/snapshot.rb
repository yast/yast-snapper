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
require "snapper/snapshot_dbus"

module Yast
  ##
  # This class represents the base class for Snapshots mostly based on Snapper
  # ones.
  class Snapshot
    include Yast::Logger

    attr_reader :number, :pre_number, :timestamp, :user

    attr_accessor :description, :cleanup, :user_data, :config, :communication

    class << self
      # @return [Hash] Mapping string with available subclass
      def types
        { "single" => SingleSnapshot, "post" => PostSnapshot, "pre" => PreSnapshot }
      end

      # @return default strategy responsable of talk with the underlying system
      def default_communication(context = nil)
        SnapshotDBus.new(context)
      end

      # @return [Array] of Snapshots
      def all(configs = nil, communication = default_communication)
        communication.all(configs).map do |attrs|
          new_by_type(attrs)
        end
      end

      def find(number, configs = nil, communication = default_communication)
        all(configs, communication).find { |s| s.number == number }
      end

      def new_by_type(attrs)
        types[attrs[:type]].new(attrs)
      end

      def get_modified_files(from, to, communication = default_communication)
        communication.get_modified_files(from, to)
      end

      def list_configs(communication = default_communication)
        communication.list_configs
      end

      def get_config(config, communication = default_communication)
        communication.get_config(config)
      end
    end

    # Generic constructor
    def initialize(attrs = {})
      raise "No instantiable class" if self.class == Yast::Snapshot
      @number = attrs[:number]
      @timestamp = attrs[:timestamp]
      @user = attrs[:uid]
      # CleanUp algorithm
      @cleanup = attrs[:cleanup] || "timeline"
      @description = attrs[:description] || ""
      @user_data = attrs[:user_data] || {}
      @communication =
        attrs[:communication] || Snapshot.default_communication(self)
      @config = attrs[:config] || Snapshot.list_configs
    end

    def save
      if number.nil?
        create
      else
        update
      end
    end

    def name
      "Snapshot"
    end

    def valid?
      true
    end

    def pre?
      false
    end

    def post?
      false
    end

    def single?
      false
    end

    def user_data_to_s
      user_data.map { |k, v| "#{k}=#{v}" }.join(", ")
    end

    def date
      timestamp.strftime("%F %T")
    end

    def update(attrs = {})
      log.info "Updating #{inspect} with #{attrs.inspect}"
      attrs.each { |k, v| send("#{k}=", v) }

      communication.update

      true
    end

    def mount_point
      communication.mount_point
    end

    def create(communication = self.communication)
      num = communication.create
      num ? Snapshot.find(num, config).number : nil
    end

    def delete(communication = self.communication)
      communication.delete
    end
  end

  class SingleSnapshot < Snapshot
    def name
      "Single"
    end

    def single?
      true
    end
  end

  class PreSnapshot < Snapshot
    def name
      "Pre"
    end

    def pre?
      true
    end

    def post(configs = nil, custom_communication = communication)
      Snapshot.all(configs, custom_communication).find { |s| s.pre_number == number }
    end
  end

  class PostSnapshot < Snapshot
    def name
      "Post"
    end

    def initialize(attrs = {})
      @pre_number = attrs[:pre_number]

      super(attrs)
    end

    def post?
      true
    end

    def valid?
      if !pre
        log.info "There is no PreSnapshot for PostSnapshot #{inspect}"
        return false
      end
      true
    end

    def pre(configs = nil, custom_communication = communication)
      @previous ||= pre_number ? Snapshot.find(pre_number, configs, custom_communication) : nil
    end
  end
end
