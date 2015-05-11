#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"


describe "Snapper#userdata_to_string" do


  it "call with empty userdata" do

    expect(Yast::Snapper.userdata_to_string({ })).to eq("")

  end


  it "call with simple userdata" do

    expect(Yast::Snapper.userdata_to_string({ "hello" => "world" })).to eq("hello=world")

  end


  it "call with complex userdata" do

    expect(Yast::Snapper.userdata_to_string({ "a" => "1", "b" => "2" })).to eq("a=1, b=2")

  end


end
