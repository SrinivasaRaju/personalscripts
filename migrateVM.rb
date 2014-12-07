#!/usr/bin/ruby

require "open3"
require "json"

require "date"

# Get current date.
current = DateTime.now

cdate = "#{current.day}#{current.month}#{current.year}"
cdate.chomp
filename = "/tmp/migrationwork_#{cdate}"

def getStatusVM (vmid, zone)
    cmd = "cloudstack -p #{zone} listVirtualMachines id=#{vmid}"
    stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
    str = stdout.read
    if str.include? "Error 500"
        puts "Given vmid is wrong "
    else
        obj = JSON.parse(str)
    end
    return obj
end

def startVMNow(zone, vmid)
	obj = 	getStatusVM(vmid, zone)
	status = obj['listvirtualmachinesresponse']['virtualmachine'][0]['state']
	if status == "Stopped"
		cmd = "cloudstack -p #{zone} startVirtualMachine id=#{vmid}"
		stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
    		obj1 = JSON.parse (stdout.read.chomp)
    		jobid = obj1['startvirtualmachineresponse']['jobid']

    		obj2 = 	getStatusVM(vmid, zone)
    		status = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']
    		puts "Starting the VM #{vmid} now"
    		while status != "Running" do
    			print "."
    			sleep 2
    			obj3 = 	getStatusVM(vmid, zone)
    			status = obj3['listvirtualmachinesresponse']['virtualmachine'][0]['state']
    		end
		puts "\n\n"
    		return 1
	elsif status == "Running"
		puts "VM #{vmid} is already up"
		puts "\n\n"
		return 2
	end
end

def getDiskInfo (vmid, zone)
    hash1 = Hash.new
    cmd = "cloudstack -p #{zone} listVolumes virtualmachineid=#{vmid}"
    stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
    str = stdout.read
    if str.include? "Error 500"
        puts "Given vmid is wrong "
    else
        obj = JSON.parse(str)
	if obj['listvolumesresponse'].length == 0
 	   puts "this is not getting disk details"
	else

        if obj['listvolumesresponse']['count'] >= 2
            array = obj['listvolumesresponse']['volume']
            array.each {|hash|
            diskid = hash['id']
            disktype = hash['type']
            diskname = hash['name']
            if disktype == "DATADISK"
            	hash1[diskid] = "#{diskname},#{disktype}"
            end
            }
        end
      end
    end
    return hash1
end

def doDetachVolume(vmid, zone, data)
    obj1 = getStatusVM(vmid, zone)
    status = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state']
    if status == "Stopped"
    	data.each_key { |diskid|  
        	cmd = "cloudstack -p #{zone} detachVolume id=#{diskid}"
            stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
            obj2 = JSON.parse(stdout1.read.chomp)
            jobid = obj2['detachvolumeresponse']['jobid']

            cmd = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
            stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
            obj2 = JSON.parse(stdout1.read.chomp)
            status = obj2['queryasyncjobresultresponse']['jobstatus']

            puts "Disk is Detaching now "
            while status != 1 do 
            	print "."
                sleep 2
                cmd1 = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
                stdin2, stdout2, stderr2, wait_thr2 = Open3.popen3("#{cmd}")
                obj3 = JSON.parse(stdout2.read.chomp)
                status = obj3['queryasyncjobresultresponse']['jobstatus']
            end
        }
	puts "\n\n"
    end
end


def doAttachVolume(vmid, zone, data)
    obj1 = getStatusVM(vmid, zone)
    status = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state']
    if status == "Running" or status == "Stopped"
	data.each_key { |diskid|  
	value = data[diskid]
        cmd = "cloudstack -p #{zone} attachVolume id=#{diskid} virtualmachineid=#{vmid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj2 = JSON.parse(stdout1.read.chomp)
        jobid = obj2['attachvolumeresponse']['jobid']

        cmd = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj2 = JSON.parse(stdout1.read.chomp)
        status = obj2['queryasyncjobresultresponse']['jobstatus']
		
	puts "\n\n"
        puts "Disk is Attached now and jobid is #{jobid} ...."
        puts "VM ID : #{vmid}, Disk ID : #{diskid}, #{value} " 

	return jobid	
    }
    end
end

def migrateVmNow (zone, vmid, stid)
	cmd1 = "cloudstack -p #{zone} migrateVirtualMachine virtualmachineid=#{vmid} storageid=#{stid}"
	stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
	obj3 = JSON.parse(stdout1.read.chomp)
	jobid = obj3['migratevirtualmachineresponse']['jobid']

	cmd1 = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
	stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
	obj1 = JSON.parse(stdout1.read.chomp)
	status = obj1['queryasyncjobresultresponse']['jobstatus']
	obj1 = getStatusVM(vmid, zone)
    	vmstatus = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state']

	puts "Migrating vm now .."
	while status != 1 do
		print "."
		sleep 4
		obj2 = getStatusVM(vmid, zone)
    		vmstatus = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']

		cmd = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
		stdin2, stdout2, stderr2, wait_thr2 = Open3.popen3("#{cmd}")
		obj3 = JSON.parse(stdout2.read.chomp)
		status = obj3['queryasyncjobresultresponse']['jobstatus']

    		if status == 2 and vmstatus != "Stopped"
    			err =  obj3['queryasyncjobresultresponse']['jobresult']['errortext']
    			puts "Migration failed with #{err}"
    		        exit	
    		end
	end 
	puts "\n\n"
end

if ARGV.length == 3
    zone = ARGV[0]
    vmid = ARGV[1]
    stid = ARGV[2]

    obj1 = getStatusVM(vmid, zone)
    vmname = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
    curxen = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['hostname']

    if obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state'] == "Running"
    	puts "Stopping #{vmname} now .."
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("cloudstack -p #{zone} stopVirtualMachine id=#{vmid} forced=true")
        obj1 = JSON.parse(stdout1.read.chomp)
        status = "Running"
        while status != "Stopped" do
        	print "."
            sleep 2
            obj2 = getStatusVM(vmid, zone)
            status = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']
        end
	print "\n\n"
        data = Hash.new
        data = getDiskInfo(vmid, zone)
        if data.length > 0
        	doDetachVolume(vmid, zone, data)
        end

        file1 = File.open(filename,'a+')
    	file1.chmod(0777)
        file1.write "#{vmname},#{vmid},#{curxen},#{data}\n"
        file1.close

        migrateVmNow(zone, vmid, stid)
        startVMNow(zone, vmid)
	jobid=""
        if data.length > 0
        	jobid=doAttachVolume(vmid, zone, data)

        str = "#{zone}|#{vmname}|#{vmid}|#{data}|#{jobid}"
        jobfile = "/tmp/jobstatus_#{cdate}"
        file1 = File.open(jobfile,'a+')
        file1.chmod(0777)
        file1.write "#{str}\n"
        file1.close
	end
    elsif obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state'] == "Stopped"
    	data = Hash.new
    	file1 = File.open(filename,'a+')
        data = getDiskInfo(vmid, zone)
        if data.length > 0
        	doDetachVolume(vmid, zone, data)
        end

        file1 = File.open(filename,'a+')
    	file1.chmod(0777)
        file1.write "#{vmname},#{vmid},#{curxen},#{data}\n"
        file1.close

        migrateVmNow(zone, vmid, stid)
        startVMNow(zone, vmid)
	jobid=""
        if data.length > 0
        	jobid=doAttachVolume(vmid, zone, data)
	str = "#{zone}|#{vmname}|#{vmid}|#{data}|#{jobid}"
	jobfile = "/tmp/jobstatus_#{cdate}"
  	file1 = File.open(jobfile,'a+')
        file1.chmod(0777)
        file1.write "#{str}\n"
        file1.close	
	end
    end
    obj1 = getStatusVM(vmid, zone)
    vmname = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
    curxen = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['hostname']

    print "\n\n"
    puts "Migration of #{vmname} is completed and now its running #{curxen} "
elsif ARGV[0] == "jobstatus"
    jobfile = "/tmp/jobstatus_4122014"
    file1 = File.open(jobfile,"r+")
    file1.each { |line|
        dat1 = line.split('|')
        zone = dat1[0]
        vmname = dat1[1]
        vmid= dat1[2]
        data = dat1[3]
        jobid = dat1[4]
        val = data.split("\"")
        diskid = val[1]
        diskname = val[3].split(",")[0]

        cmd = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3(cmd)
        obj1 = JSON.parse(stdout1.read.chomp)
        jstatus = obj1['queryasyncjobresultresponse']['jobstatus']
        if jstatus == 0
            puts "Disk #{diskname} still migrating for #{vmname} \n"
        elsif jstatus == 2
            error = obj1['queryasyncjobresultresponse']['jobresult']['errortext']
            puts "Disk #{diskname} for #{vmname} is failed to attach with #{error} \n"
        elsif jstatus == 1
            storpath = ""
            storpath = obj1['queryasyncjobresultresponse']['jobresult']['volume']['storage']
            puts "Disk #{diskname} is migrated now to #{storpath} for VM #{vmname} \n"
        end
    }
else
    puts "Please pass 3 variables to script like... migrateVM.rb [compliant|general] vmid  storageid"
end
