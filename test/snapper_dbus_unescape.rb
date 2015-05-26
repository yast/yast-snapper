#!/usr/bin/env rspec
# coding: utf-8

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"


describe "SnapperDbus#unescape" do


  it "call with nothing special" do

    expect(Yast::SnapperDbus.unescape("hello")).to eq("hello")
    expect(Yast::SnapperDbus.unescape("world").encoding).to eq(Encoding::ASCII_8BIT)

  end


  it "call with escaped UTF-8" do

    expect(Yast::SnapperDbus.unescape("sch\\xc3\\xb6n")).to eq("schön".force_encoding(Encoding::ASCII_8BIT))

  end


  it "call with slash" do

    expect(Yast::SnapperDbus.unescape("\\\\")).to eq("\\")

  end


  it "call with a hash" do

    expect(Yast::SnapperDbus.unescape({ "sch\\xc3\\xb6n" => "hier" })).to eq({ "schön".force_encoding(Encoding::ASCII_8BIT) => "hier" })

  end


end
