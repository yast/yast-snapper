#!/usr/bin/env rspec
# coding: utf-8

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

class DummyClass < Yast::Client
  def initialize
    Yast.include self, "snapper/dialogs.rb"
  end
end

describe "Yast::SnapperDialogsInclude" do
  subject { DummyClass.new }

  describe "#snapshot_modified" do
    let(:orig) { {:num => 1, :post_num => 2} }
   
    it "returns false if we have only deleted elements" do
       expect(subject.snapshot_modified(orig, {:num => 1})).to eq false
    end
   
    it "returns false if the new hash is empty" do
      expect(subject.snapshot_modified(orig, {})).to eq false
    end
       
     it "returns false if the hashes are equal" do
       expect(subject.snapshot_modified(orig, orig)).to eq false
     end
   
    it "returns true if some value has changed" do
      expect(subject.snapshot_modified(orig, {:num => 4, :post_num => 2})).to eq true
     end
   
    it "returns true if new keys has been added" do
       expect(subject.snapshot_modified(orig, {:num => 1 , :description => "desc"})).to eq true
    end
  end

end
