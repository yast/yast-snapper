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

# File:	include/snapper/dialogs.ycp
# Package:	Configuration of snapper
# Summary:	Dialogs definitions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>

module Yast

  module SnapperDialogsInclude

    include Yast::Logger

    def initialize_snapper_dialogs(include_target)
      Yast.import "UI"

      textdomain "snapper"

      Yast.import "Confirm"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Snapper"
      Yast.import "String"

      Yast.include include_target, "snapper/helps.rb"

    end


    def timestring(t)
      t.strftime("%F %T")
    end

    # transform userdata from widget to map
    def get_userdata(id)
      Snapper.string_to_userdata(UI.QueryWidget(Id(id), :Value))
    end


    # generate list of items for Cleanup combo box
    def cleanup_items(current)
      Builtins.maplist(["timeline", "number", ""]) do |cleanup|
        Item(Id(cleanup), cleanup, cleanup == current)
      end
    end


    # compare editable parts of snapshot maps
    def snapshot_modified(orig, new)
      new.any? { |k, v| orig[k] != v }
    end

    # grouped enable condition based on snapshot presence for modification widgets
    def enable_buttons(buttons, condition)
      buttons.each do |b|
        UI.ChangeWidget(Id(b), :Enabled, condition) 
      end
    end


    # Popup for modification of existing snapshot
    # @return true if new snapshot was created
    def ModifySnapshotPopup(snapshot)
      modified = false
      num = snapshot["num"] || 0
      pre_num = snapshot["pre_num"] || num
      type = snapshot["type"] || :none

      pre_index = Snapper.id2index[pre_num] || 0
      pre_snapshot = Snapper.snapshots[pre_index] || {}

      if type != :POST
        cont = VBox(
          # popup label, %{num} is number
          Label(_("Modify Snapshot %{num}") % { :num => num }),
          snapshot_term("", snapshot)
        )
      else
        cont = VBox(
          # popup label, %{pre} and %{post} are numbers
          Label(_("Modify Snapshot %{pre} and %{post}") % { :pre => pre_num, :post => num }),
          # label
          Left(Label(_("Pre (%{pre})") % { :pre => pre_num })),
          snapshot_term("pre_", pre_snapshot),
          VSpacing(),
          # label
          Left(Label(_("Post (%{post})") % { :post => num })),
          snapshot_term("", snapshot)
        )
      end

      open_modify_dialog(cont)

      pre_args = {}

      while true
        ret = UI.UserInput
        args = get_modify_args(num)
        if type == :POST
          pre_args = get_modify_args(num,"pre_") 
        end
        break if ret == :ok || ret == :cancel
      end
      UI.CloseDialog
      if ret == :ok
        if snapshot_modified(snapshot, args)
          modified = Snapper.ModifySnapshot(args)
        end
        if type == :POST && snapshot_modified(pre_snapshot, pre_args)
          modified = Snapper.ModifySnapshot(pre_args) || modified
        end
      end

      modified
    end


    # Popup for creating new snapshot
    # @return true if new snapshot was created
    def CreateSnapshotPopup(pre_snapshots)
      created = false
      pre_items = pre_snapshots.map do |s|
        Item(Id(s), s.to_s)
      end

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.5),
            HSpacing(65),
            # popup label
            Label(_("Create New Snapshot")),
            # text entry label
            InputField(Id("description"), Opt(:hstretch), _("Description"), ""),
            RadioButtonGroup(
              Id(:rb_type),
              Left(
                HVSquash(
                  VBox(
                    Left(
                      RadioButton(
                        Id("single"),
                        Opt(:notify),
                        # radio button label
                        _("Single snapshot"),
                        true
                      )
                    ),
                    Left(
                      RadioButton(
                        Id("pre"),
                        Opt(:notify),
                        # radio button label
                        _("Pre"),
                        false
                      )
                    ),
                    VBox(
                      Left(
                        RadioButton(
                          Id("post"),
                          Opt(:notify),
                          # radio button label, snapshot selection will follow
                          _("Post, paired with:"),
                          false
                        )
                      ),
                      HBox(
                        HSpacing(2),
                        Left(
                          ComboBox(Id(:pre_list), Opt(:notify), "", pre_items)
                        )
                      )
                    )
                  )
                )
              )
            ),
            # text entry label
            InputField(Id("userdata"), Opt(:hstretch), _("User data"), ""),
            # text entry label
            ComboBox(
              Id("cleanup"),
              Opt(:editable, :hstretch),
              _("Cleanup algorithm"),
              cleanup_items("")
            ),
            VSpacing(0.5),
            ButtonBox(
              PushButton(Id(:ok), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )

      enable_buttons([:post, :pre_list], !pre_items.empty?)

      ret = nil
      args = {}

      while true
        ret = UI.UserInput
        args = {
          "type"        => UI.QueryWidget(Id(:rb_type), :Value),
          "description" => UI.QueryWidget(Id("description"), :Value),
          "pre"         => UI.QueryWidget(Id(:pre_list), :Value),
          "cleanup"     => UI.QueryWidget(Id("cleanup"), :Value),
          "userdata"    => get_userdata("userdata")
        }
        break if ret == :ok || ret == :cancel
      end
      UI.CloseDialog
      created = Snapper.CreateSnapshot(args) if ret == :ok
      created
    end

    
    # Popup for deleting existing snapshot
    # @return true if snapshot was deleted
    def DeleteSnapshotPopup(snapshots)
      snaps = []
      post_snaps = []
      snapshots.each do |s|
        if s["type"] != :POST
          snaps << s["num"]  
        else
          post_snaps << {:pre_num => s["pre_num"], :num => s["num"]}
        end
      end
      
      nums = snaps + post_snaps.map {|k| "#{k[:pre_num]}&#{k[:num]}"}

      # yes/no popup question
      if Popup.YesNo(_("You have selected those snapshots: %{num}") % { :num => nums.join(",") } )
        Snapper.DeleteSnapshot(snaps)
        post_snaps.each do |k|
          Snapper.DeleteSnapshot([k[:pre_num], k[:num]])
        end
        true
      end
    end


    # Summary dialog
    # @return dialog result
    def SummaryDialog
      # summary dialog caption
      caption = _("Snapshots")

      # update list of snapshots
      Wizard.SetContentsButtons(
        caption,
        snapshots_table,
        Ops.get_string(@HELPS, "summary", ""),
        Label.BackButton,
        Label.CloseButton
      )
      Wizard.HideBackButton
      Wizard.HideAbortButton

      UI.SetFocus(Id(:snapshots_table))
      refresh_buttons
      summary_event_loop
    end


    def generate_ui_file_tree(subtree)
      return subtree.children.map do |file|
        Item(Id(file.fullname), term(:icon, file.icon), file.name, false,
             generate_ui_file_tree(file))
      end
    end


    def format_diff(diff, textmode)
      lines = Builtins.splitstring(String.EscapeTags(diff), "\n")
      if !textmode
        # colorize diff output
        lines.map! do |line|
          case line[0]
          when "+"
            line = "<font color=blue>#{line}</font>"
          when "-"
            line = "<font color=red>#{line}</font>"
          end
          line
        end
      end
      ret = lines.join("<br>")
      if !textmode
        # show fixed font in diff
        ret = "<pre>" + ret + "</pre>"
      end
      return ret
    end


    # @return dialog result
    def ShowDialog

      # dialog caption
      caption = _("Selected Snapshot Overview")

      display_info = UI.GetDisplayInfo
      textmode = display_info["TextMode"] || false

      previous_filename = ""
      current_filename = ""
      current_file = nil

      snapshot = Snapper.selected_snapshot
      snapshot_num = snapshot["num"]

      pre_num = snapshot["pre_num"] || snapshot_num
      pre_index = Snapper.id2index[pre_num] || 0
      description = Snapper.snapshots[pre_index]["description"] || ""

      pre_date = timestring(Snapper.snapshots[pre_index]["date"])
      date = timestring(snapshot["date"])
      type = snapshot["type"] || :NONE
      combo_items = Snapper.snapshots.each_with_object([]) do |s, combo_items|
        id = s["num"]
        if id != snapshot_num
          # '%1: %2' means 'ID: description', adapt the order if necessary
          combo_items << Item(
            Id(id),
            _("%1s: %2s") % [id, s["description"]]
          )
        end
      end

      from = snapshot_num
      to = 0 # current system
      if snapshot["type"] == :POST
        from = snapshot["pre_num"] || 0
        to = snapshot_num
      elsif snapshot["type"] == :PRE
        to = snapshot["post_num"] || 0
      end

      # busy popup message
      Popup.ShowFeedback("", _("Calculating changed files..."))
      files_tree = Snapper.ReadModifiedFilesTree(from, to)
      Popup.ClearFeedback()

      snapshot_name = "#{snapshot_num}"

      # helper function: show the specific modification between snapshots
      show_file_modification = lambda do |file, from2, to2|
        content = VBox()
        # busy popup message
        Popup.ShowFeedback("", _("Calculating file modifications..."))
        modification = Snapper.GetFileModification(file.fullname, from2, to2)
        Popup.ClearFeedback

        status = modification["status"] || []
        
        # Add label to the content
        if status.include? "created"
          content << Left(Label(_("New file was created.")))
        elsif status.include? "removed"
          content << Left(Label(_("File was removed.")))
        elsif status.include? "no_change"
          content << Left(Label(_("File content was not changed.")))
        elsif status.include? "none"
          content << Left(Label(_("File does not exist in either snapshot.")))
        elsif status.include? "diff"
          content << Left(Label(_("File content was modified.")))
        end
        if status.include? "mode"
          content << Left(
            Label(
              # text label, %1, %2 are file modes (like '-rw-r--r--')
              Builtins.sformat(
                _("File mode was changed from '%1' to '%2'."),
                modification["mode1"],
                modification["mode2"]
              )
            )
          )
        end
        if status.include? "user"
          content << Left(
            Label(
              # text label, %1, %2 are user names
              Builtins.sformat(
                _("File user ownership was changed from '%1' to '%2'."),
                modification["user1"],
                modification["user2"]
              )
            )
          )
        end
        if status.include? "group"
          # label
          content << Left(
            Label(
              # text label, %1, %2 are group names
              Builtins.sformat(
                _("File group ownership was changed from '%1' to '%2'."),
                modification["group1"],
                modification["group2"]
              )
            )
          )
        end

        if modification.has_key? "diff"
          content << RichText(Id(:diff),
            format_diff(modification["diff"], textmode))
        else
          content << VStretch()
        end

        # button label
        restore_label = _("R&estore from First")
        # button label
        restore_label_single = _("Restore")

        if file.created?
          restore_label = Label.RemoveButton
          restore_label_single = Label.RemoveButton
        end

        UI.ReplaceWidget(
          Id(:diff_content),
          HBox(
            HSpacing(0.5),
            VBox(
              content,
              VSquash(
                HBox(
                  HStretch(),
                  type == :SINGLE ?
                    Empty() :
                    PushButton(Id(:restore_pre), restore_label),
                  PushButton(
                    Id(:restore),
                    type == :SINGLE ?
                      restore_label_single :
                      _("Res&tore from Second")
                  )
                )
              )
            ),
            HSpacing(0.5)
          )
        )
        if type != :SINGLE && file.deleted?
          # file removed in 2nd snapshot cannot be restored from that snapshot
          UI.ChangeWidget(Id(:restore), :Enabled, false)
        end

        nil
      end

      # create the term for selected file
      set_entry_term = lambda do
        if current_file && current_file.status != 0
          if type == :SINGLE
            UI.ReplaceWidget(
              Id(:diff_chooser),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.2),
                  RadioButtonGroup(
                    Id(:rd),
                    Left(
                      HVSquash(
                        VBox(
                          Left(
                            RadioButton(
                              Id(:diff_snapshot),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between snapshot and current system"
                              ),
                              true
                            )
                          ),
                          VBox(
                            Left(
                              RadioButton(
                                Id(:diff_arbitrary),
                                Opt(:notify),
                                # radio button label, snapshot selection will follow
                                _(
                                  "Show the difference between current and selected snapshot:"
                                ),
                                false
                              )
                            ),
                            HBox(
                              HSpacing(2),
                              # FIXME without label, there's no shortcut!
                              Left(
                                ComboBox(
                                  Id(:selection_snapshots),
                                  Opt(:notify),
                                  "",
                                  combo_items
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  ),
                  VSpacing()
                ),
                HSpacing(0.5)
              )
            )
            show_file_modification.call(current_file, snapshot_num, 0)
            UI.ChangeWidget(Id(:selection_snapshots), :Enabled, false)
          else
            UI.ReplaceWidget(
              Id(:diff_chooser),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.2),
                  RadioButtonGroup(
                    Id(:rd),
                    Left(
                      HVSquash(
                        VBox(
                          Left(
                            RadioButton(
                              Id(:diff_snapshot),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between first and second snapshot"
                              ),
                              true
                            )
                          ),
                          Left(
                            RadioButton(
                              Id(:diff_pre_current),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between first snapshot and current system"
                              ),
                              false
                            )
                          ),
                          Left(
                            RadioButton(
                              Id(:diff_post_current),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between second snapshot and current system"
                              ),
                              false
                            )
                          )
                        )
                      )
                    )
                  ),
                  VSpacing()
                ),
                HSpacing(0.5)
              )
            )
            show_file_modification.call(current_file, pre_num, snapshot_num)
          end
        else
          UI.ReplaceWidget(Id(:diff_chooser), VBox(VStretch()))
          UI.ReplaceWidget(Id(:diff_content), HBox(HStretch()))
        end

        nil
      end

      if type == :SINGLE
        tree_label = "%{num}" % { :num => snapshot_num }
        date_widget = HBox(
          # label, date string will follow at the end of line
          Label(Id(:date), _("Time of taking the snapshot:")),
          Right(Label(date))
        )
      else
        tree_label = "%{pre} && %{post}" % { :pre => pre_num, :post => snapshot_num }
        date_widget = VBox(
          HBox(
            # label, date string will follow at the end of line
            Label(Id(:pre_date), _("Time of taking the first snapshot:")),
            Right(Label(pre_date))
          ),
          HBox(
            # label, date string will follow at the end of line
            Label(Id(:post_date), _("Time of taking the second snapshot:")),
            Right(Label(date))
          )
        )
      end

      contents = HBox(
        HWeight(
          1,
          VBox(
            HBox(
              HSpacing(),
              ReplacePoint(
                Id(:reptree),
                VBox(Left(Label(Snapper.current_subvolume)), Tree(Id(:tree), tree_label, []))
              ),
              HSpacing()
            ),
            HBox(
              HSpacing(1.5),
              HStretch(),
              textmode ?
                # button label
                PushButton(Id(:open), Opt(:key_F6), _("&Open")) :
                Empty(),
              HSpacing(1.5)
            )
          )
        ),
        HWeight(
          2,
          VBox(
            Left(Label(Id(:desc), description)),
            VSquash(VWeight(1, VSquash(date_widget))),
            VWeight(
              2,
              Frame(
                "",
                HBox(
                  HSpacing(0.5),
                  VBox(
                    VSpacing(0.5),
                    VWeight(
                      1,
                      ReplacePoint(Id(:diff_chooser), VBox(VStretch()))
                    ),
                    VWeight(
                      4,
                      ReplacePoint(Id(:diff_content), HBox(HStretch()))
                    ),
                    VSpacing(0.5)
                  ),
                  HSpacing(0.5)
                )
              )
            )
          )
        )
      )

      # show the dialog contents with empty tree, compute items later
      Wizard.SetContentsButtons(
        caption,
        contents,
        type == :SINGLE ?
          Ops.get_string(@HELPS, "show_single", "") :
          Ops.get_string(@HELPS, "show_pair", ""),
        # button label
        Label.CancelButton,
        _("Restore Selected")
      )

      tree_items = generate_ui_file_tree(files_tree)

      if !tree_items.empty?
        UI.ReplaceWidget(
          Id(:reptree),
          VBox(
            Left(Label(Snapper.current_subvolume)),
            Tree(
              Id(:tree),
              Opt(:notify, :immediate, :multiSelection, :recursiveSelection),
              tree_label,
              tree_items
            )
          )
        )
        # no item is selected
        UI.ChangeWidget(:tree, :CurrentItem, nil)
      end

      current_filename = ""

      set_entry_term.call

      UI.SetFocus(Id(:tree)) if textmode

      ret = nil

      while true
        event = UI.WaitForEvent
        ret = Ops.get_symbol(event, "ID")

        previous_filename = current_filename
        current_filename = UI.QueryWidget(Id(:tree), :CurrentItem)

        if current_filename == nil
          current_filename = ""
        else
          current_filename.force_encoding(Encoding::ASCII_8BIT)
        end

        if current_filename.empty?
          current_file = nil
        else
          current_file = files_tree.find(current_filename)
        end

        # other tree events
        if ret == :tree
          # seems like tree widget emits 2 SelectionChanged events
          if current_filename != previous_filename
            set_entry_term.call
            UI.SetFocus(Id(:tree)) if textmode
          end

        elsif ret == :diff_snapshot
          if type == :SINGLE
            UI.ChangeWidget(Id(:selection_snapshots), :Enabled, false)
            show_file_modification.call(current_file, snapshot_num, 0)
          else
            show_file_modification.call(current_file, pre_num, snapshot_num)
          end

        elsif ret == :diff_arbitrary || ret == :selection_snapshots
          UI.ChangeWidget(Id(:selection_snapshots), :Enabled, true)
          selected_num = Convert.to_integer(
            UI.QueryWidget(Id(:selection_snapshots), :Value)
          )
          show_file_modification.call(current_file, pre_num, selected_num)

        elsif ret == :diff_pre_current
          show_file_modification.call(current_file, pre_num, 0)

        elsif ret == :diff_post_current
          show_file_modification.call(current_file, snapshot_num, 0)

        elsif ret == :abort || ret == :cancel || ret == :back
          break

        elsif (ret == :restore_pre || ret == :restore && type == :SINGLE) &&
            current_file.created?
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to delete the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from current system?"
                ),
                Snapper.GetFileFullPath(current_filename)
              )
            )
            Snapper.RestoreFiles(
              ret == :restore_pre ? pre_num : snapshot_num,
              [current_filename]
            )
          end
          next

        elsif ret == :restore_pre
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to copy the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from snapshot '%2' to current system?"
                ),
                Snapper.GetFileFullPath(current_filename),
                pre_num
              )
            )
            Snapper.RestoreFiles(pre_num, [current_filename])
          end
          next

        elsif ret == :restore
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to copy the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from snapshot '%2' to current system?"
                ),
                Snapper.GetFileFullPath(current_filename),
                snapshot_num
              )
            )
            Snapper.RestoreFiles(snapshot_num, [current_filename])
          end
          next

        elsif ret == :next

          filenames = UI.QueryWidget(Id(:tree), :SelectedItems)
          filenames.map!{ |filename| filename.force_encoding(Encoding::ASCII_8BIT) }

          # remove filenames not changed between the snapshots, e.g. /foo if
          # only /foo/bar changed
          filenames.delete_if { |filename| files_tree.find(filename[1..-1]).status == 0 }

          if filenames.empty?
            # popup message
            Popup.Message(_("No file was selected for restoring."))
            next
          end

          to_restore = filenames.map do |filename|
            String.EscapeTags(Snapper.prepend_subvolume(filename))
          end

          if Popup.AnyQuestionRichText(
               # popup headline
              _("Restoring files"),
              # popup message, %1 is snapshot number, %2 list of files
              Builtins.sformat(
                _(
                  "<p>These files will be restored from snapshot '%1':</p>\n" +
                    "<p>\n" +
                    "%2\n" +
                    "</p>\n" +
                    "<p>Files existing in original snapshot will be copied to current system.</p>\n" +
                    "<p>Files that did not exist in the snapshot will be deleted.</p>Are you sure?"
                ),
                pre_num,
                to_restore.join("<br>")
              ),
              60,
              20,
              Label.YesButton,
              Label.NoButton,
              :focus_no
            )
            Snapper.RestoreFiles(pre_num, filenames)
            break
          end
          next

        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end

      end

      deep_copy(ret)
    end


    private
    
    def get_modify_args(num,prefix = "")
      {
        "num"         => num,
        "description" => UI.QueryWidget(Id("#{prefix}description"), :Value),
        "cleanup"     => UI.QueryWidget(Id("#{prefix}cleanup"), :Value),
        "userdata"    => get_userdata("#{prefix}userdata")
      }
    end

    def refresh_buttons
      selected = UI.QueryWidget(Id(:snapshots_table), :SelectedItems) || []
      enable_buttons([:show, :modify], selected.size == 1)
      enable_buttons([:delete], selected.size >= 1)
      enable_buttons([:configs], Snapper.configs.size > 1)
    end


    def get_selected_items(widget_id)
      selected = UI.QueryWidget(Id(widget_id), :SelectedItems) || []
    end

    def check_one_selection(selected)
      if selected.size != 1
        Popup.Message(_("You have to select one snapshot for this action."))
        false
      else 
        true
      end
    end

    # main loop for summary dialog
    def summary_event_loop
      ret = nil
      while true
        ret = UI.UserInput
        selected = get_selected_items(:snapshots_table)
      
        case ret
        when :abort, :cancel, :back
          really_abort? ? break : next
        when :show 
          next if !check_one_selection(selected)
          if Snapper.snapshots[selected.first]["type"] == :PRE
            # popup message
            Popup.Message(
              _(
                "This 'Pre' snapshot is not paired with any 'Post' one yet.\nShowing differences is not possible."
              )
            )
            next
          end
          # `POST snapshot is selected from the pair
          Snapper.selected_snapshot = Snapper.snapshots[selected.first] || {}
          break
        when :configs
          config = "#{UI.QueryWidget(Id(ret), :Value)}"
          if config != Snapper.current_config
            Snapper.current_config = config
            update_snapshots
          end
        when :create
          if CreateSnapshotPopup(pre_lonely_snapshots_num)
            update_snapshots
          end
        when :modify
          next if !check_one_selection(selected)
          if ModifySnapshotPopup(Snapper.snapshots[selected.first] || {})
            update_snapshots
          end

        when :delete
          if DeleteSnapshotPopup(selected_snapshots(selected))
            update_snapshots
          end
        when :next
          break
        when :snapshots_table
          enable_buttons([:show, :modify], selected.size == 1)
          enable_buttons([:delete], selected.size >= 1)
        else
          log.error "unexpected retcode: #{ret}"
        end
      end
      ret
    end

    def really_abort?
      Popup.ReallyAbort(true)
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      return :abort if !Confirm.MustBeRoot

      Wizard.RestoreHelp(@HELPS["read"])
      Snapper.Init() ? :next : :abort
    end

    def open_modify_dialog(content)
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.5),
            HSpacing(65),
            content,
            VSpacing(0.5),
            ButtonBox(
              PushButton(Id(:ok), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )
    end

    def snapshot_term(prefix, data)
      HBox(
        HSpacing(),
        Frame(
          "",
          HBox(
            HSpacing(0.4),
            VBox(
              # text entry label
              InputField(
                Id("#{prefix}description"),
                Opt(:hstretch),
                _("Description"),
                data["description"]
              ),
              # text entry label
              InputField(
                Id("#{prefix}userdata"),
                Opt(:hstretch),
                _("User data"),
                Snapper.userdata_to_string(data["userdata"])
              ),
              Left(
                ComboBox(
                  Id("#{prefix}cleanup"),
                  Opt(:editable, :hstretch),
                  # combo box label
                  _("Cleanup algorithm"),
                  cleanup_items(data["cleanup"])
                )
              )
            ),
            HSpacing(0.4)
          )
        ),
        HSpacing()
      )
    end

    def update_snapshots
      # busy popup message
      Popup.Feedback("", _("Reading list of snapshots...")) do
        Snapper.ReadSnapshots()
      end

      UI.ChangeWidget(Id(:snapshots_table), :Items, get_snapshot_items)
      refresh_buttons
    end

    def table_item(s,id)
      num = s["num"] || 0
      start_date = (num != 0) ? timestring(s["date"]) : ""
      user_data = Snapper.userdata_to_string(s["userdata"])
      type = (s["type"] == :SINGLE) ?  "Single" : "Pre"

      Item(Id(id), num, type, start_date, "", s["description"], user_data)
    end


    def post_table_item(s,id)
      index = Snapper.id2index[s["pre_num"]]
      pre = Snapper.snapshots[index]
      desc = pre["description"] || ""
      num = s["num"] || 0
      end_date = (num != 0) ? timestring(s["date"]) : ""
      user_data = Snapper.userdata_to_string(s["userdata"])
      start_date = timestring(pre["date"])
      num = %|#{pre["num"]} & #{num}|
      type = _("Pre & Post")

      Item(Id(id), num, type, start_date, end_date, desc, user_data)
    end

    def snapshot_has_pre?(s)
      pre = s["pre_num"] || 0 # pre canot be 0
      index = Snapper.id2index[pre] || -1
      !(pre == 0 || index == -1)
    end

    def snapshot_has_post?(s)
      !(s["post_num"].to_i == 0)
    end

    # Pre Snapshots with a Post are skiped because
    # related information is showed in the Post Item
    # @return Item list for Snapshots Table
    def get_snapshot_items
      snapshot_items = []

      Snapper.snapshots.each_with_index do |s,i|
        case s["type"]
        when :SINGLE
          snapshot_items << table_item(s,i)
        when :POST
          if !snapshot_has_pre?(s)
            log.warning "something was wrong with snapshot #{s.inspect}"
          else
            snapshot_items << post_table_item(s,i)
          end
        when :PRE
          # 0 means there's no post
          if !snapshot_has_post?(s)
            log.info %|pre snapshot #{s["num"]} does not have post|
            snapshot_items << table_item(s,i)
          else
            log.info %|skipping pre snapshot: #{s["num"]}|
          end
        else
          raise %|Error, unknown snapshot_type #{s["type"]}|
        end
      end
      snapshot_items
    end

    def config_items
      Snapper.configs.map do |config|
        Item(Id(config), config, config == Snapper.current_config)
      end
    end

    def config_select
      HBox(
        # combo box label
        Label(_("Current Configuration")),
        ComboBox(Id(:configs), Opt(:notify), "", config_items),
        HStretch()
      )
    end

    def snapshots_table
      VBox(
        config_select,
        Table(
          Id(:snapshots_table),
          Opt(:notify, :keepSorting, :multiSelection, :immediate),
          Header(
            # table header
            _("ID"),
            _("Type"),
            _("Start Date"),
            _("End Date"),
            _("Description"),
            _("User Data")
          ),
          get_snapshot_items
        ),
        snapshots_table_footer
      )
    end

    def snapshots_table_footer
      HBox(
        # button label
        PushButton(Id(:show), Opt(:default), _("Show Changes")),
        PushButton(Id(:create), Label.CreateButton),
        # button label
        PushButton(Id(:modify), _("Modify")),
        PushButton(Id(:delete), Label.DeleteButton),
        HStretch()
      )
    end

    def selected_snapshots(selection)
      selection.map do |s|
        Snapper.snapshots[s]
      end
    end

    def pre_lonely_snapshots_num
      pre_lonely_snapshots.map {|s| s["num"] }
    end

    def pre_lonely_snapshots
      Snapper.snapshots.select do |s| 
        (s["type"] == :PRE) && (s["post_num"].to_i == 0)
      end 
    end

  end

end
