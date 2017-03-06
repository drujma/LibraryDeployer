#! /usr/bin/env ruby

require 'fileutils'
require 'inifile'

class ConfigurationSettings
    def initialize(iniFilePath)
        puts iniFilePath
        @ini_content = IniFile.new(:filename => iniFilePath, :parameter => '=', :comment => [';','#'])
        puts @ini_content
    end
end


def checkAndCompile(directory, is_dist_clean)
    Dir.chdir(directory)

    #Handle better the access to the git function
    describe = `git describe --long --dirty`
    is_git   = !describe.include?("fatal")
    is_dirty = describe.include? "dirty"
=begin
    if  !is_git or is_dirty 
        abort "Sorry there's something wrong with the directory #{Dir.pwd}"
    end
=end
    if is_dist_clean
        system("make distclean")
    end

    `/opt/Qt5.6.1/5.6/gcc_64/bin/qmake \"CONFIG+=debug_and_release debug_and_release_target build_all\"`

    system("make -j4")
end


def cleanDsp(dsp_dir)
    Dir.chdir("#{dsp_dir}/extResources")
    if File.directory?("#{Dir.pwd}/eltGraphs")
        FileUtils.remove_dir("eltGraphs")
    end

    if File.directory?("#{Dir.pwd}/eltElintGraphs")
        FileUtils.remove_dir("eltElintGraphs")
    end
end



c = ConfigurationSettings.new("/home/laboratorio/Projects/libraryBuilder.ini")
exit(1)


home_content = Dir.entries(Dir.home)

if not home_content.include?("Projects")
    abort "Can't find Projects dir"
end

puts "Entering in Projects directory"
Dir.chdir("#{Dir.home}/Projects/")

puts "Looking for Elt Libraries"
dsp_dirs = Array.new
for entry in Dir.entries(Dir.pwd)
    downcased = entry.downcase
    if downcased.include?("elt") and downcased.include?("graphs") and not downcased.include?("elint")
        elt_graphs_dir  = File.expand_path(entry, Dir.pwd)
        puts "\tFound #{entry}"
    end
    
    if downcased.include?("elint") and downcased.include?("graphs")
        elt_elint_graphs_dir = File.expand_path(entry, Dir.pwd)
        puts "\tFound #{entry}"
    end    
    
    if downcased =~ /aers(.*)hmi(.*)dsp(.*)/
        dsp_dirs.push(entry)
    end
end

puts
if dsp_dirs.count > 0
    print "I found the following AERS HMI DSP directories "
    print dsp_dirs
    print " pleaselease select one: "
end

hmi_dsp_dir = ""
loop do
    answer = gets.chomp
    hmi_dsp_dir = File.expand_path(answer, Dir.pwd)
    break if dsp_dirs.include?(answer)
end

print "Do you want to perform a deep clean? ([Y/N])"
is_dist_clean = gets.chomp.downcase.eql?("y")

checkAndCompile(elt_graphs_dir, is_dist_clean)
Dir.chdir("./scripts")
puts `./createKit.sh &`


Dir.chdir("#{elt_elint_graphs_dir}/ELT_ELINT_GRAPHS_LIB/ext_resources")
if File.directory?("#{Dir.pwd}/eltGraphs")
    FileUtils.remove_dir("eltGraphs")
end

fileName = ""
for file in Dir.entries("#{elt_graphs_dir}/scripts")
    if file =~ /eltGraphs(.+)\.tar\.gz/
        fileName = file
    end
end

if !fileName.empty?
    system("tar xzf #{elt_graphs_dir}/scripts/#{fileName}")
else
     abort "File Not Found"
end


checkAndCompile("#{elt_elint_graphs_dir}/ELT_ELINT_GRAPHS_LIB", is_dist_clean)

Dir.chdir(File.expand_path("../scripts", Dir.pwd))

puts `./prepare_include_dir.sh &`
puts `./createKit.sh &`

cleanDsp(hmi_dsp_dir)

if !fileName.empty?
    `tar xzf #{elt_graphs_dir}/scripts/#{fileName}`
else
     abort "File Not Found"
end

fileName = ""
for file in Dir.entries("#{elt_elint_graphs_dir}/scripts")
    if file =~ /eltElintGraphs(.+)\.tar\.gz/
        fileName = file
    end
end

if !fileName.empty?
    `tar xzf #{elt_elint_graphs_dir}/scripts/#{fileName}`
else
     abort "File Not Found"
end


