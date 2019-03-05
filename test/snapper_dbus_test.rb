#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "SnapperDbus"

describe "SnapperDbus" do
  describe "#escape" do
    it "call with nothing special" do
      expect(Yast::SnapperDbus.send(:escape, "hello")).to eq("hello")
    end

    it "call with UTF-8" do
      expect(Yast::SnapperDbus.send(:escape, "schön")).to eq("sch\\xc3\\xb6n".force_encoding(Encoding::ASCII_8BIT))
    end

    it "call with slash" do
      expect(Yast::SnapperDbus.send(:escape, "\\")).to eq("\\\\")
    end

    it "call with a hash" do
      expect(Yast::SnapperDbus.send(:escape, { "schön" => "hier" }))
        .to eq({ "sch\\xc3\\xb6n".force_encoding(Encoding::ASCII_8BIT) => "hier" })
    end
  end

  describe "#unescape" do
    it "call with nothing special" do
      expect(Yast::SnapperDbus.send(:unescape, "hello")).to eq("hello")
      expect(Yast::SnapperDbus.send(:unescape, "world").encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "call with escaped UTF-8" do
      expect(Yast::SnapperDbus.send(:unescape, "sch\\xc3\\xb6n")).to eq("schön".force_encoding(Encoding::ASCII_8BIT))
    end

    it "call with slash" do
      expect(Yast::SnapperDbus.send(:unescape, "\\\\")).to eq("\\")
    end

    it "call with a hash" do
      expect(Yast::SnapperDbus.send(:unescape, { "sch\\xc3\\xb6n" => "hier" }))
        .to eq({ "schön".force_encoding(Encoding::ASCII_8BIT) => "hier" })
    end
  end
end
