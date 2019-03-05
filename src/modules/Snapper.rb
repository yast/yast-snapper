# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2015 Novell, Inc. All Rights Reserved.
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

# File:	modules/Snapper.ycp
# Summary:	Snapper settings, input and output functions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# Representation of the configuration of snapper.
# Input and output routines.

require "yast"

module Yast
  class SnapperClass < Module

    include Yast::Logger

    attr_reader :current_config
    attr_reader :current_subvolume

    def main
      Yast.import "UI"
      textdomain "snapper"

      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "SnapperDbus"

      # global list of all snapshot
      @snapshots = []

      @selected_snapshot = {}

      # mapping of snapshot number to index in snapshots list
      @id2index = {}

      # list of configurations
      @configs = []

      @current_config = ""
      @current_subvolume = ""
    end

    def current_config=(current_config)
      @current_config = current_config

      if !@current_config.empty?
        @current_subvolume = get_config[1]
      else
        @current_subvolume = ""
      end

      log.info("current_config:#{@current_config} current_subvolume:#{@current_subvolume}")
    end

    # Return Tree of files modified between given snapshots
    # Map is recursively describing the filesystem structure; helps to build Tree widget contents
    def ReadModifiedFilesTree(from, to)
      SnapperDbus.create_comparison(@current_config, from, to)
      files = SnapperDbus.get_files(@current_config, from, to)
      SnapperDbus.delete_comparison(@current_config, from, to)

      root = Tree.new("", nil)

      files.each do |file|
        root.add(file["filename"], file["status"])
      end

      return root
    end

    def get_config
      return SnapperDbus.get_config(@current_config)

    rescue Exception => e
      Report.Error(_("Failed to get config:" + "\n" + e.message))
      return {}
    end

    def prepend_subvolume(filename)
      if @current_subvolume == "/"
        return filename
      else
        return @current_subvolume + filename
      end
    end

    # Return the path to given snapshot
    def GetSnapshotPath(snapshot_num)
      return SnapperDbus.get_mount_point(@current_config, snapshot_num)

    rescue Exception => e
      Report.Error(_("Failed to get snapshot mount point:" + "\n" + e.message))
      return ""
    end

    # Return the full path to the given file from currently selected configuration (subvolume)
    # @param [String] file path, relatively to current config
    # GetFileFullPath ("/testfile.txt") -> /abc/testfile.txt for /abc subvolume
    def GetFileFullPath(file)
      return prepend_subvolume(file)
    end

    # Describe what was done with given file between given snapshots
    # - when new is 0, meaning is 'current system'
    def GetFileModification(file, old, new)
      ret = {}
      file1 = Builtins.sformat("%1%2", GetSnapshotPath(old), file)
      file2 = Builtins.sformat("%1%2", GetSnapshotPath(new), file)
      file2 = GetFileFullPath(file) if new == 0

      Builtins.y2milestone("comparing '%1' and '%2'", file1, file2)

      if FileUtils.Exists(file1) && FileUtils.Exists(file2)
        status = ["no_change"]
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "/usr/bin/diff -u '%1' '%2'",
              String.Quote(file1),
              String.Quote(file2)
            )
          )
        )
        if Ops.get_string(out, "stderr", "") != ""
          Builtins.y2warning("out: %1", out)
          Ops.set(ret, "diff", Ops.get_string(out, "stderr", ""))
        # the file diff
        elsif Ops.get(out, "stdout") != ""
          status = ["diff"]
          ret["diff"] = out["stdout"].encode(Encoding::UTF_8, { :invalid => :replace })
        end

        # check mode and ownerships
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "/usr/bin/ls -ld -- '%1' '%2' | /usr/bin/cut -f 1,3,4 -d ' '",
              String.Quote(file1),
              String.Quote(file2)
            )
          )
        )
        parts = Builtins.splitstring(Ops.get_string(out, "stdout", ""), " \n")

        if Ops.get(parts, 0, "") != Ops.get(parts, 3, "")
          status = Builtins.add(status, "mode")
          Ops.set(ret, "mode1", Ops.get(parts, 0, ""))
          Ops.set(ret, "mode2", Ops.get(parts, 3, ""))
        end
        if Ops.get(parts, 1, "") != Ops.get(parts, 4, "")
          status = Builtins.add(status, "user")
          Ops.set(ret, "user1", Ops.get(parts, 1, ""))
          Ops.set(ret, "user2", Ops.get(parts, 4, ""))
        end
        if Ops.get(parts, 2, "") != Ops.get(parts, 5, "")
          status = Builtins.add(status, "group")
          Ops.set(ret, "group1", Ops.get(parts, 2, ""))
          Ops.set(ret, "group2", Ops.get(parts, 5, ""))
        end
        Ops.set(ret, "status", status)
      elsif FileUtils.Exists(file1)
        Ops.set(ret, "status", ["removed"])
      elsif FileUtils.Exists(file2)
        Ops.set(ret, "status", ["created"])
      else
        Ops.set(ret, "status", ["none"])
      end
      deep_copy(ret)
    end

    # Read the list of snapshots
    def ReadSnapshots
      snapshot_maps = SnapperDbus.list_snapshots(@current_config)

      @snapshots = []
      i = 0
      Builtins.foreach(snapshot_maps) do |snapshot|
        id = Ops.get_integer(snapshot, "num", 0)
        next if id == 0 # ignore the 'current system'

        if snapshot["type"] == :PRE
          snapshot_maps.each do |x|
            if x["type"] == :POST && x["pre_num"] == snapshot["num"]
              snapshot["post_num"] = x["num"]
            end
          end
        end

        log.debug("snapshot:#{snapshot}")
        @snapshots = Builtins.add(@snapshots, snapshot)
        Ops.set(@id2index, id, i)
        i = Ops.add(i, 1)
      end
      true
    end

    def ReadConfigs
      @configs = SnapperDbus.list_configs

      if @configs.include?("root")
        self.current_config = "root"
      elsif !@configs.empty?
        self.current_config = @configs[0]
      else
        self.current_config = ""
      end
    end

    # Create new snapshot
    # Return true on success
    def CreateSnapshot(args)
      case args["type"]
      when "single"
        SnapperDbus.create_single_snapshot(@current_config, args["description"], args["cleanup"],
                                           args["userdata"])
      when "pre"
        SnapperDbus.create_pre_snapshot(@current_config, args["description"], args["cleanup"],
                                        args["userdata"])
      when "post"
        SnapperDbus.create_post_snapshot(@current_config, args["pre"], args["description"],
                                         args["cleanup"], args["userdata"])
      end

      return true

    rescue Exception => e
      Report.Error(_("Failed to create new snapshot:" + "\n" + e.message))
      return false
    end

    # Modify existing snapshot
    # Return true on success
    def ModifySnapshot(args)
      SnapperDbus.set_snapshot(@current_config, args["num"], args["description"], args["cleanup"],
                               args["userdata"])

      return true

    rescue Exception => e
      Report.Error(_("Failed to modify snapshot:" + "\n" + e.message))
      return false
    end

    # Delete existing snapshot
    # Return true on success
    def DeleteSnapshot(nums)
      SnapperDbus.delete_snapshots(@current_config, nums)

      return true

    rescue Exception => e
      Report.Error(_("Failed to delete snapshot:" + "\n" + e.message))
      return false
    end

    # Init snapper (get configs and snapshots)
    # Return true on success
    def Init
      # We do not set help text here, because it was set outside
      Progress.New(
        # Snapper read dialog caption
        _("Initializing Snapper"),
        " ",
        2,
        [
          # Progress stage 1/2
          _("Read list of configurations"),
          # Progress stage 2/2
          _("Read list of snapshots")
        ],
        [
          # Progress step 1/2
          _("Reading list of configurations"),
          # Progress step 2/2
          _("Reading list of snapshots"),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage

      begin
        ReadConfigs()
      rescue Exception => e
        Report.Error(_("Querying snapper configurations failed:") + "\n" + e.message)
        return false
      end

      if @configs.empty?
        Report.Error(_("No snapper configurations exist. You have to create one or more
configurations to use yast2-snapper. The snapper command line
tool can be used to create configurations."))
      end

      Progress.NextStage

      begin
        ReadSnapshots()
      rescue Exception => e
        Report.Error(_("Querying snapper snapshots failed:") + "\n" + e.message)
        return false
      end

      Progress.NextStage

      return true
    end

    # Return the given file mode as octal number
    def GetFileMode(file)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("/bin/stat --printf=%%a '%1'", String.Quote(file))
        )
      )
      mode = Ops.get_string(out, "stdout", "")
      return 644 if mode == nil || mode == ""
      Builtins.tointeger(mode)
    end

    # Copy given files from selected snapshot to current filesystem
    # @param [Fixnum] snapshot_num snapshot identifier
    # @param [Array<String>] files list of full paths to files (but excluding subvolume)
    # @return success
    def RestoreFiles(snapshot_num, files)
      files = deep_copy(files)
      ret = true
      Builtins.y2milestone("going to restore files %1", files)

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(60),
            # label for log window
            LogView(Id(:log), _("Restoring Files..."), 8, 0),
            ProgressBar(Id(:progress), "", Builtins.size(files), 0),
            PushButton(Id(:ok), Label.OKButton)
          ),
          HSpacing(1.5)
        )
      )

      UI.ChangeWidget(Id(:ok), :Enabled, false)
      progress = 0
      Builtins.foreach(files) do |file|
        UI.ChangeWidget(Id(:progress), :Value, progress)
        orig = Ops.add(GetSnapshotPath(snapshot_num), file)
        full_path = GetFileFullPath(file)
        dir = Builtins.substring(
          full_path,
          0,
          Builtins.findlastof(full_path, "/")
        )
        if !FileUtils.Exists(orig)
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/bin/rm -rf -- '%1'", String.Quote(full_path))
          )
          Builtins.y2milestone("removing '%1' from system", full_path)
          # log entry (%1 is file name)
          UI.ChangeWidget(
            Id(:log),
            :LastLine,
            Builtins.sformat(_("Deleted %1\n"), full_path)
          )
        elsif FileUtils.CheckAndCreatePath(dir)
          Builtins.y2milestone(
            "copying '%1' to '%2' (dir: %3)",
            orig,
            file,
            dir
          )
          if FileUtils.IsDirectory(orig) == true
            stat = Convert.to_map(SCR.Read(path(".target.stat"), orig))
            if !FileUtils.Exists(full_path)
              SCR.Execute(path(".target.mkdir"), full_path)
            end
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/bin/chown -- %1:%2 '%3'",
                Ops.get_integer(stat, "uid", 0),
                Ops.get_integer(stat, "gid", 0),
                String.Quote(full_path)
              )
            )
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/bin/chmod -- %1 '%2'",
                GetFileMode(orig),
                String.Quote(full_path)
              )
            )
          else
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/bin/cp -a -- '%1' '%2'",
                String.Quote(orig),
                String.Quote(full_path)
              )
            )
          end
          UI.ChangeWidget(Id(:log), :LastLine, Ops.add(full_path, "\n"))
        else
          Builtins.y2milestone(
            "failed to copy file '%1' to '%2' (dir: %3)",
            orig,
            full_path,
            dir
          )
          # log entry (%1 is file name)
          UI.ChangeWidget(
            Id(:log),
            :LastLine,
            Builtins.sformat(_("%1 skipped\n"), full_path)
          )
        end
        Builtins.sleep(100)
        progress = Ops.add(progress, 1)
      end

      UI.ChangeWidget(Id(:progress), :Value, progress)
      UI.ChangeWidget(Id(:ok), :Enabled, true)

      UI.UserInput
      UI.CloseDialog

      ret
    end

    # convert hash with userdata to a string
    # { "a" => "1", "b" => "2" } -> "a=1, b=2"
    def userdata_to_string(userdata)
      return userdata.map { |k, v| "#{k}=#{v}" }.join(", ")
    end

    # convert string with userdata to a hash
    # "a=1, b=2" -> { "a" => "1", "b" => "2" }
    def string_to_userdata(string)
      string.split(",").map do |s|
        if s.include?("=")
          s.split("=", 2).map { |t| t.strip }
        else
          [s.strip, ""]
        end
      end.to_h
    end

  private

    class Tree

      attr_accessor :name, :status
      attr_reader :children

      def initialize(name, parent)
        @name = name
        @status = 0
        @parent = parent
        @children = []
      end

      def each
        if @parent != nil
          yield self
        end
        @children.each do |subtree|
          subtree.each do |e|
            yield e
          end
        end
      end

      def fullname
        return @parent ? @parent.fullname + "/" + @name : @name
      end

      def created?
        return @status & 0x01 != 0
      end

      def deleted?
        return @status & 0x02 != 0
      end

      def icon
        if @status == 0
          return "yast-gray-dot.png"
        elsif created?
          return "yast-green-dot.png"
        elsif deleted?
          return "yast-red-dot.png"
        else
          return "yast-yellow-dot.png"
        end
      end

      def add(fullname, status)
        a, b = fullname.split("/", 2)
        return add(b, status) if fullname.start_with? "/" # leading /

        i = @children.index{ |x| x.name == a }

        if i
          if b
            @children[i].add(b, status)
          else
            @children[i].status = status
          end
        else
          subtree = Tree.new(a, self)
          if b
            subtree.add(b, status)
          else
            subtree.status = status
          end
          @children << subtree
        end
      end

      def find(fullname)
        a, b = fullname.split("/", 2)
        return find(b) if fullname.start_with? "/" # leading /

        i = @children.index{ |x| x.name == a }

        if !i
          return nil
        end

        if !b
          return @children[i]
        else
          return @children[i].find(b)
        end
      end

    end

  public

    publish :variable => :snapshots, :type => "list <map>"
    publish :variable => :selected_snapshot, :type => "map"
    publish :variable => :id2index, :type => "map <integer, integer>"
    publish :variable => :configs, :type => "list <string>"
    publish :function => :GetSnapshotPath, :type => "string (integer)"
    publish :function => :GetFileFullPath, :type => "string (string)"
    publish :function => :GetFileModification, :type => "map (string, integer, integer)"
    publish :function => :ReadSnapshots, :type => "boolean ()"
    publish :function => :ReadConfigs, :type => "boolean ()"
    publish :function => :DeleteSnapshot, :type => "boolean (map)"
    publish :function => :ModifySnapshot, :type => "boolean (map)"
    publish :function => :CreateSnapshot, :type => "boolean (map)"
    publish :function => :Init, :type => "boolean ()"
    publish :function => :RestoreFiles, :type => "boolean (integer, list <string>)"

  end

  Snapper = SnapperClass.new
  Snapper.main
end
