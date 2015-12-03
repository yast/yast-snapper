require_relative 'spec_helper'
require 'yast'
require 'dbus'
require_relative '../src/lib/snapper/snapshot.rb'

describe Yast2::Snapper::Snapshot, "with default strategy" do
  let(:strategy) { Yast2::Snapper::Snapshot.default_strategy }
  let(:output_path) { load_yaml_fixture("snapper-list.yml") }
    
  before do
    allow(strategy).to receive(:list_configs).and_return(["opt","var"])
    allow(strategy).to receive(:list_snapshots).with("var").and_return(output_path["var"])
    allow(strategy).to receive(:list_snapshots).with("opt").and_return(output_path["opt"])
  end
  
  describe ".all" do

    let(:current) { 1 }
     
    it "returns a list with all the snapshots if not config given" do
      total = output_path["var"].size + output_path["opt"].size - (2 * current)
      expect(Yast2::Snapper::Snapshot.all.size).to eq (total)
    end

    it "returns a list with the snapshots for a specific config" do
      var_size = output_path["var"].size - current
      opt_size = output_path["opt"].size - current
      expect(Yast2::Snapper::Snapshot.all("var").size).to eq var_size
      expect(Yast2::Snapper::Snapshot.all("opt").size).to eq opt_size
    end

    it "raises an error if the config not exist" do
      allow(strategy).to receive(:list_snapshots).with("not_exist").and_raise DBus::Error.new("config not found")

      expect { Yast2::Snapper::Snapshot.all("not_exist") }.to raise_error(DBus::Error)
    end

  end

  describe ".find" do

    context "without passing config paramater" do 

      it "returns an exception when num does not exist" do
        expect(Yast2::Snapper::Snapshot.find(100)).to be_nil
      end

      it "returns a snapshot object when num exist" do
        expect(Yast2::Snapper::Snapshot.find(5).class).to eq (Yast2::Snapper::Snapshot)
      end

      it "returns the correct snapshot" do
        expect(Yast2::Snapper::Snapshot.find(5).number).to eq 5
      end

      it "can't found the current snapshot" do
        expect(Yast2::Snapper::Snapshot.find(0)).to be_nil
      end
    end

    context "finding in a config given" do

      it "returns an exception when num is not present" do
        expect(Yast2::Snapper::Snapshot.find(1, "opt")).to be_nil
      end

      it "returns a snapshot object when num exist" do
        expect(Yast2::Snapper::Snapshot.find(5, "var").class).to eq (Yast2::Snapper::Snapshot)
      end
      
      it "returns the correct snapshot" do
        expect(Yast2::Snapper::Snapshot.find(5, "var").number).to eq 5
      end

    end
  end

  describe "#pre" do

    it "returns the previous snapshot object" do
      expect(Yast2::Snapper::Snapshot.find(7).pre.class).to eq(Yast2::Snapper::Snapshot)
    end

    it "returns the correct snapshot" do
      expect(Yast2::Snapper::Snapshot.find(7).pre.number).to eq(4)
    end

    it "returns nil when hasn't got pre" do
      expect(Yast2::Snapper::Snapshot.find(4).pre).to be_nil
    end

  end

  describe "#pre?" do
    let(:presnapshot) { double(Yast2::Snapper::Snapshot) }
    
    it "returns true for snapshots with type :pre or :PRE" do
      expect(Yast2::Snapper::Snapshot.find(4).pre?).to eq true
    end

    it "returns false for not pre snapshots" do
      expect(Yast2::Snapper::Snapshot.find(7).pre?).to eq false 
    end

    it "returns nil when hasn't got pre" do
      expect(Yast2::Snapper::Snapshot.find(4).pre).to be_nil
    end
  end

  describe "#post" do


    it "returns the post snapshot object" do
      expect(Yast2::Snapper::Snapshot.find(4).post.class).to eq(Yast2::Snapper::Snapshot)
    end

    it "returns the correct snapshot" do
      expect(Yast2::Snapper::Snapshot.find(4).post.number).to eq(7)
    end

    it "returns nil when hasn't got post" do
      expect(Yast2::Snapper::Snapshot.find(2).post).to be_nil
    end
  end

  describe "#post?" do
    let(:presnapshot) { double(Yast2::Snapper::Snapshot) }
    
    it "returns true for snapshots with type :pre or :PRE" do
      expect(Yast2::Snapper::Snapshot.find(7).post?).to eq true
    end

    it "returns false for not pre snapshots" do
      expect(Yast2::Snapper::Snapshot.find(4).post?).to eq false 
    end

    it "returns nil when hasn't got post" do
      expect(Yast2::Snapper::Snapshot.find(2).post).to be_nil
    end
  end


end
