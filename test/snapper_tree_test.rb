#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Snapper"

describe Yast::SnapperClass::Tree do
  subject { Yast::SnapperClass::Tree.new("", nil) }

  describe "#each" do
    it "calls block for all subtrees of instance" do
      root = subject
      root.add("a", 0)
      root.add("b", 0)

      res = ""
      root.each { |i| res << i.name }

      expect(res).to eq "ab"
    end

    it "calls on tree itself if it is not root element" do
      root = subject
      root.add("a", 0)
      ch1 = root.children.first
      ch1.add("b", 0)

      res = ""
      root.each { |i| res << i.name }

      expect(res).to eq "ab"
    end
  end

  describe "#fullname" do
    it "returns name itself for root element" do
      expect(subject.fullname).to eq ""
    end

    it "returns all parents name and name itself joined with '/'" do
      root = subject
      root.add("a", 0)
      ch1 = root.children.first
      ch1.add("b", 0)

      expect(ch1.children.first.fullname).to eq "/a/b"
    end
  end

  describe "#created?" do
    it "returns if status contain flag for created" do
      subject.status = 1
      expect(subject.created?).to eq true
    end
  end

  describe "#deleted?" do
    it "returns if status contain flag for deleted" do
      subject.status = 2
      expect(subject.deleted?).to eq true
    end
  end

  describe "#icon" do
    it "returns gray dot for zero status" do
      subject.status = 0
      expect(subject.icon).to include "gray-dot"
    end

    it "returns green dot for created node" do
      subject.status = 1
      expect(subject.icon).to include "green-dot"
    end

    it "returns red dot for deleted node" do
      subject.status = 2
      expect(subject.icon).to include "red-dot"
    end

    it "returns yellow for remaining nodes" do
      subject.status = 4
      expect(subject.icon).to include "yellow-dot"
    end
  end

  describe "#add" do
    context "name do not contain '/'" do
      it "adds new node with name and status under current one" do
        root = subject
        root.add("a", 0)

        expect(root.children.first.name).to eq "a"
      end
    end

    context "name contain '/'" do
      it "splits name to components and add node under last component" do
        root = subject
        root.add("a", 0)
        ch1 = root.children.first
        root.add("/a/b", 0)

        expect(root.children.first.children.first.name).to eq "b"
      end

      it "change status if any node full name equal passed name" do
        root = subject
        root.add("a", 0)
        ch1 = root.children.first
        root.add("/a/b", 0)
        root.add("/a/b", 1)

        expect(root.children.first.children.first.status).to eq 1
      end
    end
  end

  describe "#find" do
    it "return node matching full name" do
      root = subject
      root.add("a", 0)
      ch1 = root.children.first
      ch1.add("b", 0)

      expect(root.find("/a/b")).to eq ch1.children.first
    end

    it "returns nil if name not found" do
      root = subject
      root.add("a", 0)

      expect(root.find("/a/b")).to eq nil
    end
  end
end
