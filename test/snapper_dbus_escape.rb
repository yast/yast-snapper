#!/usr/bin/env rspec
# coding: utf-8

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"


describe "SnapperDbus#escape" do


  it "call with nothing special" do

    expect(Yast::SnapperDbus.escape("hello")).to eq("hello")

  end


  it "call with slash" do

    expect(Yast::SnapperDbus.escape("\\")).to eq("\\\\")

  end


  it "call with a hash" do

    expect(Yast::SnapperDbus.escape({ "\\" => "guitar" })).to eq({ "\\\\" => "guitar" })

  end


end
