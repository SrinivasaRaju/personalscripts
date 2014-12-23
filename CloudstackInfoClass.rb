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

end
