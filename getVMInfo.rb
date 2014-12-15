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

if zone != 'general' or zone != 'compliant'
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
allvminfo= Array.new
cc = 0
projects.each {|proj|
	projname=proj['name']
	projid=proj['id']

puts "#{projid} -- #{projname}"
	cmd1 = "cloudstack -p #{zone} listVirtualMachines listall=true hostid=#{hostid} projectid=#{projid}"
	stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")

	str1 = stdout1.read
	if str1.include? "Error 500"
		puts "Not able to get requested details "
	else
    	obj1 = JSON.parse(str1)
	end

	if obj1['listvirtualmachinesresponse'].length !=0 
		vmdata = obj1['listvirtualmachinesresponse']['virtualmachine']
		vmdata.each {|vminf|
			vmid = vminf['id']
			vmname = vminf['displayname']
    		curxen = vminf['hostname']
    		seroff = vminf['serviceofferingname']
    		vgroup = vminf['group']
    		tstr = "#{curxen},#{vmid},#{seroff},#{vgroup}"
    		allvminfo[cc]=tstr
    		cc += 1	
		}
    end	
}

cmd1 = "cloudstack -p #{zone} listVirtualMachines listall=true hostid=#{hostid}"
stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")

str1 = stdout1.read
if str1.include? "Error 500"
	puts "Not able to get requested details "
else
	obj1 = JSON.parse(str1)
end

if obj1['listvirtualmachinesresponse'].length !=0 
	vmdata = obj1['listvirtualmachinesresponse']['virtualmachine']
	vmdata.each {|vminf|
		vmid = vminf['id']
		vmname = vminf['displayname']
    	curxen = vminf['hostname']
    	seroff = vminf['serviceofferingname']
    	vgroup = vminf['group']
    	tstr = "#{curxen},#{vmid},#{seroff},#{vgroup}"
    	allvminfo[cc]=tstr
    	cc += 1	
	}
end	

allvminfo.each {|val|
	puts val
}