#!/usr/bin/ruby

require "optparse"
require "open3"
require "json"
require "date"
require "./CloudstackInfoClass"

options = {
	:zone => 'default',
	:task => 'listvm',
	:vmid => false,
	:storageid => false,
	:xenname => false,
	:verbose => false
}

CC = CloudstackInfoClass.new

OptionParser.new do |opts|
  	opts.banner = "Usage: migrationScript [options] "

  	opts.on('-v', "First Migration Script") do |v|
  		options[:verbose] = v
  	end

  	opts.on('-p', '--profile=MANDATORY', "Need to pass general/compliant") do |p|
  		options[:zone] = p
  	end

  	opts.on('-t', '--task=MANDATORY', "Pass Tasks [migration/listvm/storageinfo/statusjob]") do |p|
  		options[:task] = p
  	end

 	  opts.on('-m', '--vmid', "Pass VM ID") do |m|
  		options[:vmid] = m
  	end
	
	  opts.on('-s', '--storageid', "Pass Storage ID") do |s|
  		options[:storageid] = s
  	end

  	opts.on('-x', '--xenname', "Xen Server Name") do |x|
  		options[:xenname] = x
  	end

  	opts.on_tail("-h", "--help", <<__USAGE__) do
Show this message

Examples:
  migrationScript -p general -t listvm -x n7pdxen150  [For getting VM list from Xen]
  migrationScript -p general -t migration -m vmid -s storageid [For migration vm to different cluster]
  migrationScript -p general -t statusjob
  migrationScript -p general -t storageinfo

__USAGE__
    puts opts
    exit
    end  	
end.parse!

if options[:task] == 'listvm'
  if ARGV.length >= 1
    options[:xenname] = ARGV[0]
    allvminfo = Array.new() 
    allvminfo = CC.getAllVMfromXen(options[:zone],options[:xenname])
    data = allvminfo.uniq
    data.each {|val|
      puts val
    }
  else
    puts "Please pass xen server name to get list"
  end
end

