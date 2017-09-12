#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Snapper"

describe "SnapperDbus#escape" do
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
    expect(Yast::SnapperDbus.send(:escape, { "schön" => "hier" })).to eq({ "sch\\xc3\\xb6n".force_encoding(Encoding::ASCII_8BIT) => "hier" })
  end
end
