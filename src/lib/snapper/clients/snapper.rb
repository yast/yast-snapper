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
