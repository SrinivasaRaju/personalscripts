#!/usr/bin/ruby

require "open3"
require "json"

class GetPodClusterInfo

	def initialize

	end

#  This function will give Cluster Wise Capacity and it need envir (prod/dev) and zone(general/compliant)
#  getClusterWiseCapacity(envir, zone)
#  It returns Array with all current usage information.

    def getClusterWiseCapacity(envir, zone)
        data = Array.new
        zonedet={
        'GN7_Prod1'=>'b7fa0802-79ff-4481-b68c-d3541315fee1',
        'GN7_Dev1' => '7c1b8a2e-9107-4a0c-ba88-c483074d074b',
        'CN7_Prod1'=>'db8149d8-ebd9-4aa5-97b0-587739e27aa2',
        'CN7_Dev1' => '9e523e68-35c3-4ec8-be83-0415c25a7bba'
        }
        
        info1 = {'0' => 'Memory', '1' => 'CPU', '2' => 'Storage', '3' => 'Shared Disk', '9' => 'Local Disk'}

        cinfo="######## Compliant Cluster Usage Information ########\n"
        cinfo=cinfo + "Cluster Name  ----  CPU  ----  Memory  ----  Shared Disk  ----  Local Disk \n"
        ccpuinfo="######## Compliant CPU ########\n"
        cmeminfo="######## Compliant Memory ########\n"
        csharedinfo="######## Compliant Shared Disk ########\n"
        clocalinfo="######## Compliant Local Disk ########\n"

        ginfo="######## General Cluster Usage Information ########\n"
        ginfo=ginfo + "Cluster Name  ----  CPU  ----  Memory  ----  Shared Disk  ----  Local Disk \n"
        gcpuinfo="######## General CPU ########\n"
        gmeminfo="######## General Memory ########\n"
        gsharedinfo="######## General Shared Disk ########\n"
        glocalinfo="######## General Local Disk ########\n"

        
        if envir == 'prod' or envir == 'dev'
            if envir == 'prod'
                compzoneid=zonedet['CN7_Prod1']
                genzoneid=zonedet['GN7_Prod1']
            elsif envir == 'dev'
                compzoneid=zonedet['CN7_Dev1']
                genzoneid=zonedet['GN7_Dev1']
            end

            cmd="cloudstack -p compliant listClusters zoneid=#{compzoneid} showcapacities=true"
            stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
            obj = JSON.parse(stdout1.read.chomp)

            cc=obj['listclustersresponse']['count']

            for i in 0...cc
                cmem=0,ccpu=0,cshd=0,cloc=0 
                cname=obj['listclustersresponse']['cluster'][i]['name']
                array = obj['listclustersresponse']['cluster'][i]['capacity']
                array.each {|hash|
                    tt=hash['type']
                    if tt == 0
                        cmeminfo = cmeminfo + "#{cname} ----- #{hash['percentused']} \n"
                        cmem = hash['percentused']	
                    elsif tt == 1
                        ccpuinfo = ccpuinfo + "#{cname} ----- #{hash['percentused']} \n"
                        ccpu=hash['percentused']                
                    elsif tt == 3
                        csharedinfo = csharedinfo + "#{cname} ----- #{hash['percentused']} \n"
                    	cshd=hash['percentused']
                    elsif tt == 9
                        clocalinfo = clocalinfo + "#{cname} ----- #{hash['percentused']} \n"
                    	cloc=hash['percentused']
                    end 
                }
                cinfo = cinfo + "#{cname}  ----  #{ccpu}  ----  #{cmem}  ----  #{cshd}  ----  #{cloc} \n"
            end

            cmd1="cloudstack -p general listClusters zoneid=#{genzoneid} showcapacities=true"
            stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd1}")
            obj1 = JSON.parse(stdout1.read.chomp)

            cc1=obj1['listclustersresponse']['count']

            for i in 0...cc1
	    	gmem,gcpu,gshd,gloc=0,0,0,0 
            	cname=obj1['listclustersresponse']['cluster'][i]['name']
            	array1 = obj1['listclustersresponse']['cluster'][i]['capacity']
            	array1.each {|hash|
            	   tt1=hash['type']
                   if tt1 == 0
                    	gmeminfo = gmeminfo + "#{cname} ----- #{hash['percentused']} \n"
                    	gmem = hash['percentused']
                   elsif tt1 == 1
                    	gcpuinfo = gcpuinfo + "#{cname} ----- #{hash['percentused']} \n"
                    	gcpu = hash['percentused']
                   elsif tt1 == 3
                    	gsharedinfo = gsharedinfo + "#{cname} ----- #{hash['percentused']} \n"
                    	gshd = hash['percentused']
                   elsif tt1 == 9
                    	glocalinfo = glocalinfo + "#{cname} ----- #{hash['percentused']} \n"
                    	gloc = hash['percentused']
                   end
              	}
                ginfo = ginfo + "#{cname}  ----  #{gcpu}  ----  #{gmem}  ----  #{gshd}  ----  #{gloc} \n"
            end

            data[0]=cmeminfo
            data[1]=ccpuinfo
            data[2]=csharedinfo
            data[3]=csharedinfo

            data[4]=gmeminfo
            data[5]=gcpuinfo
            data[6]=gsharedinfo
            data[7]=gsharedinfo

            data[8]=cinfo
            data[9]=ginfo

            return data
        else
            puts "Please pass prod|dev to script"
        end
    end

    def getClusterStorageDetails(zone,cluname,dtype)
        cmd = "cloudstack -p #{zone} listClusters name=#{cluname}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj1 = JSON.parse(stdout1.read.chomp)

        clustid = obj1['listclustersresponse']['cluster'][0]['id']

        if clustid.length < 3
            puts "#{cluname} is not present in #{zone}, please check once and pass correct cluster name"
            exit
        end

        cmd = "cloudstack -p #{zone} listStoragePools clusterid=#{clustid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj1 = JSON.parse(stdout1.read.chomp)

        localStorage = Array.new
        shardStorage = Array.new
        l1,s1=0,0
        
        data = obj1['liststoragepoolsresponse']['storagepool']
        data.each {|hash|
	    totDisk,useDisk,perUsed=0,0,0
            if hash['scope'] == "CLUSTER"
                totDisk = hash['disksizetotal']
                useDisk = hash['disksizeused']
                perUsed = ((useDisk * 100)/totDisk)
                shardStorage[s1]="#{hash['id']} \t #{perUsed}"
                s1 +=1
            elsif hash['scope'] == "HOST"
                totDisk = hash['disksizetotal']
                useDisk = hash['disksizeused']
                perUsed = ((useDisk * 100)/totDisk)
                localStorage[l1] = "#{hash['id']} \t #{perUsed}" 
                l1  += 1   
            end 
        }

        cmd = "cloudstack -p #{zone} listHosts clusterid=#{clustid}"
        stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
        obj1 = JSON.parse(stdout1.read.chomp)

        host = Array.new
        h=0
        data1 = obj1['listhostsresponse']['host']
        data1.each {|hash1|
            host[h] = hash1['name']
            h +=1
        }

        if dtype == 'shared'
            return shardStorage
        elsif dtype == 'local'
            return localStorage
        elsif dtype == 'hosts'
            return host
        else
            return shardStorage | localStorage
        end
    end
end
