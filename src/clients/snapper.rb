# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
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

# File:	clients/snapper.ycp
# Package:	Configuration of snapper
# Summary:	Main file
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# Main file for snapper configuration. Uses all other files.

module Yast

  class SnapperClient < Client

    include Yast::Logger

    def main

      Yast.import "UI"

      textdomain "snapper"

      log.info("----------------------------------------")
      log.info("Snapper module started")

      Yast.import "CommandLine"
      Yast.include self, "snapper/wizards.rb"

      cmdline_description = {
        "id"         => "snapper",
        "help"       => _("Configuration of system snapshots"),
        "guihandler" => fun_ref(method(:SnapperSequence), "any ()")
      }

      ret = CommandLine.Run(cmdline_description)
      log.debug("ret=#{ret}")

      log.info("Snapper module finished")
      log.info("----------------------------------------")

      deep_copy(ret)

    end

  end

end

Yast::SnapperClient.new.main
