#!/usr/bin/env rspec
# coding: utf-8

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "snapper/snapshot"

# Dummy class for testing.
class DummyClass < Yast::Client
  def initialize
    Yast.include self, "snapper/dialogs.rb"
  end
end

describe "Yast::SnapperDialogsInclude" do
  subject { DummyClass.new }

  describe "#snapshot_modified" do
    let(:orig) { Yast::SingleSnapshot.new(number: 1, description: "test snapshot") }

    it "returns false if we have only deleted elements" do
      data = { number: 1 }
      expect(subject.snapshot_modified(orig, data)).to eq false
    end

    it "returns false if the new hash is empty" do
      data = {}
      expect(subject.snapshot_modified(orig, data)).to eq false
    end

    it "returns false if the hashes are equal" do
      data = { number: 1, description: "test snapshot" }
      expect(subject.snapshot_modified(orig, data)).to eq false
    end

    it "returns true if some value has changed" do
      data = { number: 4, pre_number: 2 }
      expect(subject.snapshot_modified(orig, data)).to eq true
    end

    it "returns true if new keys has been added" do
      data = { number: 1, description: "desc" }
      expect(subject.snapshot_modified(orig, data)).to eq true
    end
  end

end
