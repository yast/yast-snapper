#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Snapper"


describe "Snapper#string_to_userdata" do


  it "call with empty string" do

    expect(Yast::Snapper.string_to_userdata("")).to eq({ })

  end


  it "call with simple string" do

    expect(Yast::Snapper.string_to_userdata("hello=world")).to eq({ "hello" => "world" })

  end


  it "call with complex string" do

    expect(Yast::Snapper.string_to_userdata("a=1,b=2")).to eq({ "a" => "1", "b" => "2" })

  end


  it "call with complex string and space after comma" do

    expect(Yast::Snapper.string_to_userdata("a=1, b=2")).to eq({ "a" => "1", "b" => "2" })

  end


end
