#!/usr/bin/ruby

require "open3"
require "json"

if ARGV.length >= 2
    zone = ARGV[0]
    cluname = ARGV[1]
    type = ARGV[2]
    cmd = "cloudstack -p #{zone} listClusters name=#{cluname}"
    stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
    obj1 = JSON.parse(stdout1.read.chomp)

    clustid = obj1['listclustersresponse']['cluster'][0]['id']

    cmd = "cloudstack -p #{zone} listStoragePools clusterid=#{clustid}"
	stdin1, stdout1, stderr1, wait_thr1 = Open3.popen3("#{cmd}")
    obj1 = JSON.parse(stdout1.read.chomp)

    localStorage = Array.new
    shardStorage = Array.new
    l=0
    s=0
    data = obj1['liststoragepoolsresponse']['storagepool']
    data.each {|hash|
    	if hash['scope'] == "CLUSTER"
            totDisk = hash['disksizetotal']
            useDisk = hash['disksizeused']
            perUsed = ((useDisk * 100)/totDisk)
            shardStorage[s]=hash['id']+"----#{perUsed}"
            s +=1
    	elsif hash['scope'] == "HOST"
            totDisk1 = hash['disksizetotal']
            useDisk1 = hash['disksizeused']
            perUsed1 = ((useDisk1 * 100)/totDisk1)
    	    localStorage[l]=hash['id']+"\t#{perUsed}"
    	    localStorage[l]=hash['id']
    	    l +=1	
    	end	
    }

    puts "#{cluname}"
    if type == "shared"
        puts "Shared Stoage ID are"
        shardStorage.each {|arr|
            puts arr
        }
    elsif type == "local"
        puts "Local Storage ID are"
        localStorage.each {|arr|
            puts arr
        }
    else
        puts "Shared Stoage ID are"
        shardStorage.each {|arr|
            puts arr
        }
        puts "Local Storage ID are"
        localStorage.each {|arr|
            puts arr
        }
    end
else
	puts "Please pass zone and cluster name to get details"
end    
