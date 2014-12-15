#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'pp'
require 'open3'

zone = ARGV[0]
xenname = ARGV[1]

if ARGV.length < 2
	puts "Please pass two Arguments to script, Zone[general|Compliant] and Xen hostname name"
	puts "Examplet ./getVMInfo general n7pdxen023"
	exit
end

if zone != 'general' || zone != 'compliant'
	puts "First agruments much be zone [general|compliant]"
	exit
end

cmd = "cloudstack -p #{zone} listProjects listall=true"
stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
str = stdout.read
if str.include? "Error 500"
	puts "Not able to get Project Details"
else
    obj = JSON.parse(str)
end

projects = obj['listprojectsresponse']['project']

cmd1 = "cloudstack -p #{zone} listHosts name=#{xenname}"
stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
str1 = stdout1.read
if str1.include? "Error 500"
	puts "Given Host is not correct, please check give correct hostname "
else
    obj1 = JSON.parse(str1)
end

hostid=obj1['listhostsresponse']['host'][0]['id']
data= Array.new
cc = 0
projects.each {|proj|
	projname=proj['name']
	projid=proj['id']

	cmd1 = "cloudstack -p #{zone} listVirtualMachines listall=true hostid=#{hostid} projectid=#{projid}"
	stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")

	str1 = stdout1.read
	if str1.include? "Error 500"
		puts "Not able to get requested details "
	else
    	obj1 = JSON.parse(str1)
	end

	vmid = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['id']
	vmname = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
    curxen = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['hostname']
    seroff = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['serviceofferingname']
    vgroup = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['group']
    tstr = "#{curxen},#{vmid},#{seroff},#{vgroup}"
    data[cc]=tstr
    cc += 1
}