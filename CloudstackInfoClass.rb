#!/usr/bin/ruby

require "open3"
require "json"

class CloudstackInfoClass

	def initialize

	end

    def getCommandStatus(cmd)
        stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
        data = stdout.read
        es = wait_thr.value
        if es.success?
            obj = JSON.parse(data)
            status=0
        else
            obj = JSON.parse(data)
            status=1
        end
        return obj,status
    end

#  This function is for getting all VM's list in one xen server and it need zone(general/compliant) and Xen Name 
#  getAllVMfromXen(zone, xenname)
#  It will return Array that contains All VM's list

    def getAllVMfromXen(zone, xenname)

        cmd = "cloudstack -p #{zone} listProjects listall=true"
        obj,status=getCommandStatus(cmd)
        #stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
        #str = stdout.read
        #if str.include? "Error 500"
        #    puts "Not able to get Project Details"
        #else
        #    obj = JSON.parse(str)
        #end
        if status == 1
                
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

	if obj1['listhostsresponse'].length < 1
	   puts "#{xenname} host is not found in #{zone}, please check and pass correct hostname"
	   exit
	end
        hostid=obj1['listhostsresponse']['host'][0]['id']
        allvminfo= Array.new
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

            if obj1['listvirtualmachinesresponse'].length !=0 
                vmdata = obj1['listvirtualmachinesresponse']['virtualmachine']
                vmdata.each {|vminf|
                vmid = vminf['id']
                vmname = vminf['displayname']
                curxen = vminf['hostname']
                seroff = vminf['serviceofferingname']
                tempname = vminf['templatename']
                vgroup = vminf['group']
                instname = vminf['instancename']
                tstr = "#{curxen},#{vmid},#{vmname},#{seroff},#{tempname},#{vgroup}"
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
                tempname = vminf['templatename']
            	vgroup = vminf['group']
            	instname = vminf['instancename']
                tstr = "#{curxen},#{vmid},#{vmname},#{seroff},#{tempname},#{vgroup}"
            	allvminfo[cc]=tstr
            	cc += 1 
       	    }
        end     
        return allvminfo
    end 

#  This function is for getting VM status and it need VMID and Zone(general/compliant) 
#  getVMStatus(vmid,zone)
#  It will return json obj that contains All VM information
    def getVMStatus(vmid,zone)
        cmd = "cloudstack -p #{zone} listVirtualMachines id=#{vmid} listall=true"
        stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
        str = stdout.read
        if str.include? "Error 500"
            puts "Given vmid is wrong "
        else
            obj = JSON.parse(str)
        end
        return obj
    end


#  This function is for Starting VM status and it need VMID and Zone(general/compliant) 
#  startVMNow(zone,vmid)
    def startVMNow(zone, vmid)
        obj =   getVMStatus(vmid, zone)
        status = obj['listvirtualmachinesresponse']['virtualmachine'][0]['state']
        if status == "Stopped"
            cmd = "cloudstack -p #{zone} startVirtualMachine id=#{vmid}"
            stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
            obj1 = JSON.parse (stdout.read.chomp)
            jobid = obj1['startvirtualmachineresponse']['jobid']

            obj2 =  getVMStatus(vmid, zone)
            status = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']
            puts "Starting the VM #{vmid} now"
            while status != "Running" do
                print "."
                sleep 2
                obj3 =  getVMStatus(vmid, zone)
                status = obj3['listvirtualmachinesresponse']['virtualmachine'][0]['state']
            end
            puts "\n\n"
        elsif status == "Running"
            puts "VM #{vmid} is already up"
            puts "\n\n"
        end
    end

#  This function is for getting Extra Disk in VM and it need VMID and Zone(general/compliant) 
#  getDiskInfo(vmid, zone)
#  It will return HASH with all extra disk information
    def getDiskInfo(vmid, zone)
        hash1 = Hash.new
        cmd = "cloudstack -p #{zone} listVolumes virtualmachineid=#{vmid} listall=true"
        stdin, stdout, stderr, wait_thr = Open3.popen3("#{cmd}")
        str = stdout.read
        if str.include? "Error 500"
            puts "Given vmid is wrong "
        else
            obj = JSON.parse(str)
            if obj['listvolumesresponse'].length == 0
                puts "this vm is not getting disk details"
            else

                if obj['listvolumesresponse']['count'] >= 2
                    array = obj['listvolumesresponse']['volume']
                    array.each {|hash|
                    diskid = hash['id']
                    disktype = hash['type']
                    diskname = hash['name']
                    if disktype == "DATADISK"
                        hash1[diskid] = "#{diskname}"
                    end
                    }
                end
            end
        end
        return hash1
    end

#  This function will detach all Extra Disk in VM and it need VMID, Zone(general/compliant) and Disk Array
#  doDetachVolume(vmid, zone, data)
#  
    def doDetachVolume(vmid, zone, data)
        obj1 = getVMStatus(vmid, zone)
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

#  This function will attach all Extra Disk in VM after migration and it need VMID, Zone(general/compliant) and Disk Array
#  doAttachVolume(vmid, zone, data)
#  It return Hash with disk and jobid
    def doAttachVolume(vmid, zone, data)
        obj1 = getVMStatus(vmid, zone)
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

#  This function will migrate the VM to different cluster and it need Zone(general/compliant), VMID and New Cluster Storage ID
#  vmMigration(zone, vmid, stid)
#  
    def vmMigration(zone, vmid, stid)
        cmd1 = "cloudstack -p #{zone} migrateVirtualMachine virtualmachineid=#{vmid} storageid=#{stid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
        obj3 = JSON.parse(stdout1.read.chomp)
        jobid = obj3['migratevirtualmachineresponse']['jobid']

        cmd1 = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
        obj1 = JSON.parse(stdout1.read.chomp)
        status = obj1['queryasyncjobresultresponse']['jobstatus']
        obj1 = getVMStatus(vmid, zone)
        vmstatus = obj1['listvirtualmachinesresponse']['virtualmachine'][0]['state']

        puts "Migrating vm now .."
        while status != 1 do
            print "."
            sleep 4
            obj2 = getVMStatus(vmid, zone)
            vmstatus = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']

            cmd = "cloudstack -p #{zone} queryAsyncJobResult jobid=#{jobid}"
            stdin2, stdout2, stderr2, wait_thr2 = Open3.popen3("#{cmd}")
            obj3 = JSON.parse(stdout2.read.chomp)
            status = obj3['queryasyncjobresultresponse']['jobstatus']

            if status == 2 and vmstatus == "Stopped"
                err =  obj3['queryasyncjobresultresponse']['jobresult']['errortext']
                puts "Migration failed with #{err}"
                exit    
            end
        end 
        puts "\n\n"
    end

#  This function will check whether target storage is free or not and it need Zone(general/compliant) and New Cluster Storage ID
#  getStorageStatus(zone, stid)
#  It return Total Percentage is current used.
    def getStorageStatus(zone, stid)
        cmd = "cloudstack -p #{zone} listStoragePools id=#{stid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj1 = JSON.parse(stdout1.read.chomp)

        name = obj1['liststoragepoolsresponse']['storagepool'][0]['name']
        totDisk = obj1['liststoragepoolsresponse']['storagepool'][0]['disksizetotal']
        useDisk = obj1['liststoragepoolsresponse']['storagepool'][0]['disksizeused']
    
        perUsed = ((useDisk * 100)/totDisk)
        return perUsed
    end

# This function is for writing data into file for later reference

    def writeInfotoFile(filename,info)
        file1 = File.open(filename,'a+')
        if not File.world_writable?(filename)
            file1.chmod(0777)
        end
        file1.write "#{info}\n"
        file1.close
    end   

# This function is for checking whether vm is local and storage, need to pass zone, vmid and storage id
# checkVMisShared(zone, vmid, stid)
# It return 1 or 0 (success = 0 and failed = 1)

    def checkVMisShared(zone, vmid, stid)
        obj2 = getVMStatus(vmid, zone)
        vmstatus = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['state']
        vmname = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['displayname']
        vmseroff = obj2['listvirtualmachinesresponse']['virtualmachine'][0]['serviceofferingname']
        
        cmd = "cloudstack -p #{zone} listStoragePools id=#{stid}"
        obj1,status=getCommandStatus(cmd)
        stname = obj1['liststoragepoolsresponse']['storagepool'][0]['name']    

        if vmseroff =~ /local/ and stname !~ /Local/
            puts "VM is local and passed shared Storage ID"
	        return 1
        elsif vmseroff =~ /shared/ and stname =~ /Local/
            puts "VM is shared and Storage ID is local"
            return 1
        else
            cmd1 = "cloudstack -p #{zone} listVolumes virtualmachineid=#{vmid} listall=true"
            obj,status=getCommandStatus(cmd1)
            if obj['listvolumesresponse'].length == 0
                puts "this vm is not getting disk details"
                return 1
            else
                cc = obj['listvolumesresponse']['count']
                if cc == 1
                    disktype = obj['listvolumesresponse'][0]['type']
                    storageloc = obj['listvolumesresponse'][0]['storage']
                    stype = obj['listvolumesresponse'][0]['storagetype']

                    if disktype == 'ROOT' and stype == 'local' and stname !~ /Local/
                        puts "VM is local and passed shared storage"
                        return 1
                    else
                        return 0
                    end 
                else
                    rootstype=""
                    datastype=""        
                    array = obj['listvolumesresponse']['volume']
                    array.each {|hash|
                        diskid = hash['id']
                        disktype = hash['type']
                        diskname = hash['name']
                    
                        if disktype == 'ROOT'
                            rootstype = hash['storagetype']
                        elsif disktype == 'DATADISK'
                            datastype = hash['storagetype']
                        end 
                    }

                    if datastype == 'shared' and rootstype == 'local'
                        puts "VM is #{vmname} and root disk is #{rootstype}"
                        return 1
                    elsif datastype == 'shared' and rootstype == 'local' and stname !~ /Local/
                        puts "VM is #{datastype} and #{rootstype} and #{stname}"
                        return 1
                    else
                        return 0
                    end
                end
            end
        end    
    end 
end
