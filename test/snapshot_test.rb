require_relative "spec_helper"

require "dbus"

require "snapper/snapshot"

describe Yast::Snapshot do
  let(:communication) { Yast::SnapshotDBus.new }
  let(:subject) { Yast::Snapshot }
  let(:output_path) { load_yaml_fixture("snapper-list.yml") }

  before do
    allow(subject).to receive(:default_communication) { communication }
    allow(communication).to receive(:list_configs).and_return(["opt", "var"])
    allow(communication).to receive(:list_snapshots)
      .with("var").and_return(output_path["var"])
    allow(communication).to receive(:list_snapshots)
      .with("opt").and_return(output_path["opt"])
  end

  describe ".all" do

    let(:current) { 1 }

    context "without arguments" do
      it "returns a list of existing snapshots" do
        total = output_path["var"].size + output_path["opt"].size - (2 * current)
        expect(subject.all.size).to eql(total)
      end
    end

    context "given a config as argument" do
      it "returns a list with the snapshots for given config" do
        var_size = output_path["var"].size - current
        opt_size = output_path["opt"].size - current
        expect(subject.all("var").size).to eq var_size
        expect(subject.all("opt").size).to eq opt_size
      end

      it "raises an error if the config not exist" do
        allow(communication).to receive(:list_snapshots)
          .with("not_exist").and_raise DBus::Error.new("config not found")

        expect { subject.all("not_exist") }.to raise_error(DBus::Error)
      end
    end

  end

  describe ".find" do

    context "without passing config paramater" do

      it "returns an exception when num does not exist" do
        expect(subject.find(100)).to be_nil
      end

      it "returns a snapshot object when num exist" do
        expect(subject.find(5).class)
          .to eq(Yast::PostSnapshot)
      end

      it "returns the correct snapshot" do
        expect(subject.find(5).number).to eq 5
      end

      it "can't found the current snapshot" do
        expect(subject.find(0)).to be_nil
      end
    end

    context "finding in a config given" do

      it "returns an exception when num is not present" do
        expect(subject.find(1, "opt")).to be_nil
      end

      it "returns a snapshot object when num exist" do
        expect(subject.find(5, "var").class)
          .to eq(Yast::PostSnapshot)
      end

      it "returns the correct snapshot" do
        expect(subject.find(5, "var").number).to eq 5
      end

    end
  end

  describe ".new_by_type" do
    context "when given attributes contains type equals 'single'" do
      let(:attrs) { { type: "single" } }

      it "returns a SingleSnapshot" do
        expect(subject.new_by_type(attrs).class).to eq(Yast::SingleSnapshot)
      end
    end
    context "when given attributes contains type equals 'pre'" do
      let(:attrs) { { type: "pre" } }

      it "returns a PreSnapshot" do
        expect(subject.new_by_type(attrs).class).to eq(Yast::PreSnapshot)
      end
    end
    context "when given attributes contains type equals 'post'" do
      let(:attrs) { { type: "post" } }

      it "returns a PostSnapshot" do
        expect(subject.new_by_type(attrs).class).to eq(Yast::PostSnapshot)
      end
    end
  end

  describe ".list_configs" do
    before do
      allow(communication).to receive(:list_configs) { ["opt", "var"] }
    end
    it "returns an array with current snapper configs" do
      expect(subject.list_configs).to eql ["opt", "var"]
    end
  end
end

describe Yast::PreSnapshot do
  let(:communication) { Yast::SnapshotDBus.new }
  let(:output_path) { load_yaml_fixture("snapper-list.yml") }

  before do
    allow(Yast::Snapshot).to receive(:default_communication) { communication }
    allow(communication).to receive(:list_configs).and_return(["opt", "var"])
    allow(communication).to receive(:list_snapshots)
      .with("var").and_return(output_path["var"])
    allow(communication).to receive(:list_snapshots)
      .with("opt").and_return(output_path["opt"])
  end

  describe "#post" do
    let(:subject) { Yast::Snapshot.find(4) }

    it "returns the post snapshot object" do
      expect(subject.class).to eql(Yast::PreSnapshot)
      expect(subject.post.class).to eq(Yast::PostSnapshot)
    end

    it "returns the correct snapshot" do
      expect(subject.post.number).to eq(7)
    end

    it "returns nil when hasn't got post" do
      expect(Yast::Snapshot.find(2).post).to be_nil
    end
  end
end

describe Yast::PostSnapshot do
  let(:subject) { Yast::PostSnapshot }
  let(:communication) { Yast::SnapshotDBus.new }
  let(:output_path) { load_yaml_fixture("snapper-list.yml") }

  before do
    allow(Yast::Snapshot).to receive(:default_communication) { communication }
    allow(communication).to receive(:list_configs).and_return(["opt", "var"])
    allow(communication).to receive(:list_snapshots)
      .with("var").and_return(output_path["var"])
    allow(communication).to receive(:list_snapshots)
      .with("opt").and_return(output_path["opt"])
  end

  describe "#pre" do
    let(:subject) { Yast::Snapshot.find(7) }
    it "returns the previous snapshot object" do
      expect(subject.class).to eql(Yast::PostSnapshot)
      expect(subject.pre.class).to eq(Yast::PreSnapshot)
      expect(subject.pre.number).to eq(4)
    end

  end
end
