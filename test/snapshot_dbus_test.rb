#!/usr/bin/env rspec
# coding: utf-8

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"

describe Yast::SnapshotDBus do
  let(:snapshot) { Yast::SnapshotDBus.new }

  describe "#escape" do

    it "call with nothing special" do
      expect(snapshot.send(:escape, "hello")).to eq("hello")
    end

    it "call with UTF-8" do
      expect(snapshot.send(:escape, "schön"))
        .to eq("sch\\xc3\\xb6n".force_encoding(Encoding::ASCII_8BIT))
    end

    it "call with slash" do
      expect(snapshot.send(:escape, "\\")).to eq("\\\\")
    end

    it "call with a hash" do
      expect(snapshot.send(:escape, "schön" => "hier"))
        .to eq("sch\\xc3\\xb6n".force_encoding(Encoding::ASCII_8BIT) => "hier")
    end

  end

  describe "#unescape" do

    it "call with nothing special" do
      expect(snapshot.send(:unescape, "hello"))
        .to eq("hello")
      expect(snapshot.send(:unescape, "world").encoding)
        .to eq(Encoding::ASCII_8BIT)
    end

    it "call with escaped UTF-8" do
      expect(snapshot.send(:unescape, "sch\\xc3\\xb6n"))
        .to eq("schön".force_encoding(Encoding::ASCII_8BIT))
    end

    it "call with slash" do
      expect(snapshot.send(:unescape, "\\\\")).to eq("\\")
    end

    it "call with a hash" do
      expect(snapshot.send(:unescape, "sch\\xc3\\xb6n" => "hier"))
        .to eq("schön".force_encoding(Encoding::ASCII_8BIT) => "hier")
    end

  end
end
