#!/usr/bin/ruby

require "open3"
require "json"

class CloudstackInfoClass

	def initialize

	end

#  This function is for getting all VM's list in one xen server and it need zone(general/compliant) and Xen Name 
#  getAllVMfromXen(zone, xenname)
#  It will return Array that contains All VM's list

    def getAllVMfromXen(zone, xenname)

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
                instname = vminf['instancename']
                tstr = "#{curxen},#{vmid},#{vmname},#{instname},#{seroff},#{vgroup}"
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
            	instname = vminf['instancename']
            	tstr = "#{curxen},#{vmid},#{vmname},#{instname},#{seroff},#{vgroup}"
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

            if status == 2 and vmstatus != "Stopped"
                err =  obj3['queryasyncjobresultresponse']['jobresult']['errortext']
                puts "Migration failed with #{err}"
                exit    
            end
        end 
        puts "\n\n"
    end

#  This function will check whether target storage is free or not and it need Zone(general/compliant) and New Cluster Storage ID
#  getStorageStatus(zone, stid)
#  It returns Total Percentage is current used.
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



end
