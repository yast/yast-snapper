#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"


describe Yast::Snapper do
  SNAPSHOT_DATE = "2015/07/11 12:30:00 +0100"

  describe "#string_to_userdata" do

    it "call with empty string" do
      expect(Yast::Snapper.string_to_userdata("")).to eq({ })
    end

    it "call with simple string" do
      expect(Yast::Snapper.string_to_userdata("hello=world")).to eq({ "hello" => "world" })
    end

    it "call with complex string" do
      expect(Yast::Snapper.string_to_userdata("a=1,b=2")).to eq({ "a" => "1", "b" => "2" })
    end

    it "call with complex string and space after comma" do
      expect(Yast::Snapper.string_to_userdata("a=1, b=2")).to eq({ "a" => "1", "b" => "2" })
    end

  end

  describe "#userdata_to_string" do

    it "call with empty userdata" do
      expect(Yast::Snapper.userdata_to_string({ })).to eq("")
    end

    it "call with simple userdata" do
      expect(Yast::Snapper.userdata_to_string({ "hello" => "world" })).to eq("hello=world")
    end

    it "call with complex userdata" do
      expect(Yast::Snapper.userdata_to_string({ "a" => "1", "b" => "2" })).to eq("a=1, b=2")
    end

  end


  describe ".ReadConfigs" do
    before do
      allow(Yast::SnapperDbus).to receive(:list_configs).and_return(configs)
    end
    
    context "when no config present" do
      let(:configs) { [] }

      it "returns the empty string" do
        expect(Yast::Snapper.ReadConfigs).to eq ""
      end

    end

    context "when as least some config is present" do
      let(:configs) { ["snap_opt", "snap_var"] }

      before do
        allow(Yast::SnapperDbus).to receive(:list_snapshots).with("snap_var")
      end
      
      it "returns the first config read" do
        expect(Yast::Snapper.ReadConfigs).to eq "snap_opt"
      end
  
      it "initializes configs correctly" do
        Yast::Snapper.ReadConfigs
        expect(Yast::Snapper.configs).to include "snap_var"
        expect(Yast::Snapper.configs).to include "snap_opt"
      end

      it "set the current_config field as the first config read" do
        Yast::Snapper.ReadConfigs
        expect(Yast::Snapper.current_config).to eq "snap_opt"
      end

    end

  end

end
