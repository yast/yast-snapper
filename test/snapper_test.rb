#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Snapper"

describe Yast::Snapper do
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
