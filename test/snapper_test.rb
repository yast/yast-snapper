#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Snapper"

describe Yast::Snapper do
  describe "GetFileModification" do
    # Quite mocking test just for ensuring bsc#1195021 does not happen again
    context "when there are differences" do
      before do
        allow(subject).to receive(:GetSnapshotPath).with(anything).and_return("")
        allow(Yast::SCR).to receive(:Execute).with(anything, /diff/)
          .and_return({ "stderr" => "", "stdout" => "Found differences: \xA1 \xA1" })
        allow(Yast::SCR).to receive(:Execute).with(anything, /ls/)
          .and_return("mode1 user1 group1 mode2 mode2 user2 group2")
        allow(Yast::FileUtils).to receive(:Exists).and_return(true)
      end

      it "does not crash while encoding" do
        result = subject.GetFileModification("fake_file_1", 2, 3)

        expect(result).to be_a(Hash)
        expect(result["diff"]).to include("Found differences")
      end
    end
  end

  describe "#userdata_to_string" do
    it "call with empty userdata" do
      expect(Yast::Snapper.userdata_to_string({})).to eq("")
    end

    it "call with simple userdata" do
      expect(Yast::Snapper.userdata_to_string({ "hello" => "world" })).to eq("hello=world")
    end

    it "call with complex userdata" do
      expect(Yast::Snapper.userdata_to_string({ "a" => "1", "b" => "2" })).to eq("a=1, b=2")
    end
  end

  describe "#string_to_userdata" do
    it "call with empty string" do
      expect(Yast::Snapper.string_to_userdata("")).to eq({})
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
end
