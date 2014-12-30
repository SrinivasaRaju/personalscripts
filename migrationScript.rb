#!/usr/bin/ruby

require "optparse"
require "open3"
require "json"
require "date"
require "./CloudstackInfoClass"
require "./getPodClusterInfo"

options = {
	:zone => 'default',
	:task => 'listvm',
	:vmid => false,
	:storageid => false,
	:xenname => false,
  	:clustname => false,
  	:zonedet => false,
	:verbose => false
}

CC = CloudstackInfoClass.new
PP = GetPodClusterInfo.new

OptionParser.new do |opts|
  	opts.banner = "Usage: migrationScript.rb -p zone -p task [options] "

  	opts.on('-v', "Migration Script Help Page") do |v|
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

    	opts.on('-z', '--poddet', "Pod Name [prod/dev]") do |z|
      		options[:zonedet] = z
    	end

    	opts.on('-c', '--clustname', "Pass Cluster Name") do |c|
      		options[:clustname] = c
    	end

  	opts.on('-x', '--xenname', "Xen Server Name") do |x|
  		options[:xenname] = x
  	end

  	opts.on_tail("-h", "--help", <<__USAGE__) do
Show this message

Examples:
  migrationScript.rb -p general -t listvm -x n7pdxen150  [For getting VM list from Xen]
  migrationScript.rb -p general -t migrate -m vmid -s storageid [For migration vm to different cluster]
  migrationScript.rb -p general -t statusjob
  migrationScript.rb -p general -t podinfo -z [prod/dev]
  migrationScript.rb -p general -t clusterinfo -c clustername
__USAGE__
    puts opts
    exit
    end  	
end.parse!


# Get current date.
current = DateTime.now
cdate = "#{current.day}#{current.month}#{current.year}"
cdate.chomp

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

elsif options[:task] == 'migrate'
  puts "#{options[:zone]},#{options[:vmid]},#{options[:storageid]}"
  if options[:vmid] == true and options[:storageid] == true
    perUsed = CM.getStorageStatus(options[:zone], options[:storageid])
puts perUsed
exit
    if perUsed >= 90
      puts "Already #{stid} is filled up #{perUsed}, please use any other storage"
      exit
    end

    obj1 = CM.getVMStatus(options[:vmid], options[:zone])
    vmname = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
    curxen = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['hostname']
    status = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state']
    if status == "Running"
      puts "Stopping #{vmname} now .."
      cmd="cloudstack -p #{options[:zone]} stopVirtualMachine id=#{options[:vmid]} forced=true"

      obj,stat = CM.getCommandStatus(cmd)
      status = "Running"
      if stat == 0
        while status != "Stopped" do
          print "."
          sleep 2
          obj2 = CM.getVMStatus(options[:vmid], options[:zone])
          status = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']
        end
        print "\n\n"
      else
        puts "Failed to stop the vm #{vmname}, please vm on cloudstack once"  
      end  
    elsif status == "Stopped"
      puts "Already vm is stopped .. and continuing with migration work ..."
    end

    #Below steps will get the additional disk information for this vm
    data = Hash.new
    data = CM.getDiskInfo(options[:vmid], options[:zone])

    #Now Detaching additional disk from this vm and storaging information in file
    if data.length > 0
      doDetachVolume(vmid, zone, data)
    end

    filename = "/tmp/migrationwork_#{cdate}"
    str="#{vmname},#{vmid},#{curxen},#{data}\n"
    CM.writeInfotoFile(filename,str)        
        
    #Now this vm will be migration to new storage
    CM.vmMigration(options[:zone], options[:vmid], options[:storageid])

    #Now starting the VM after migration is completed
    CM.startVMNow(options[:zone], options[:vmid])
    jobid=""
    if data.length > 0
      jobid=CM.doAttachVolume(vmid, zone, data)
      str = "#{zone}|#{vmname}|#{vmid}|#{data}|#{jobid}"
      jobfile = "/tmp/jobstatus_#{cdate}"
      CM.writeInfotoFile(jobfile,str)
    end

    obj1 = CM.getVMStatus(options[:vmid], options[:zone])
    vmname = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
    curxen = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['hostname']

    print "\n\n"
    puts "Migration of #{vmname} is completed and now its running on #{curxen} "
  else  
    puts "Need to pass vm and storage id for migration"
    puts "migrationScript.rb -p general -t migrate -m vmid -s storageid [For migration vm to different cluster]" 
  end 

elsif options[:task] == 'podinfo'
  data = Array.new
  if options[:zonedet] == true
    options[:zonedet]=ARGV[0]
    data=PP.getClusterWiseCapacity(options[:zonedet],options[:zone])
    if options[:zone] == "general"
      puts "#{data[9]}"
    elsif options[:zone] == "compliant"
      puts "#{data[8]}"
    end
  else
    puts "Please pass [prod/dev] to script with -z"
    puts "migrationScript.rb -p general -t podinfo -z [prod/dev]"
  end
end
