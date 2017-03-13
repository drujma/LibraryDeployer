#! /usr/bin/env ruby

require 'fileutils'
require 'inifile'

class Settings
    attr_reader :configuration
    def initialize(iniFilePath)
        ini_content = IniFile.new(:filename => iniFilePath, :parameter => '=', :comment => [';','#'])
        @configuration = ini_content['CONFIG']
    end

    # Define on self, since it's  a class method
    def method_missing(method_sym, *arguments, &block)
        # the first argument is a Symbol, so you need to_s it if you want to pattern match
        methodString = method_sym.to_s
        if @configuration.keys.include? methodString
            @configuration[methodString]
        else
            super
        end
    end
end

class LibraryCompiler
    attr_reader :describe, :library_home
    def initialize(libraryDirectory)
        @library_home = libraryDirectory
        makeDirectory = `find #{libraryDirectory} -maxdepth 1 -name \"*.pro\"`
        makeDirectory = makeDirectory.split
        if makeDirectory.size == 0
            makeDirectory = `find #{libraryDirectory} -maxdepth 2 -name \"*.pro\"`
            makeDirectory = makeDirectory.split
            selected = makeDirectory.select{|s| !s.downcase.include? 'demo'}     
            puts "Selected #{selected}" 
            Dir.chdir(File.dirname(selected.first))
        else
            selected = makeDirectory
            puts "Selected #{selected}" 
            Dir.chdir(File.dirname(selected.first))
        end
        @describe = `git describe --long --dirty`
    end

    def versioned?()
       return (!@describe.include?("fatal"))
    end

    def dirty?()
        return @describe.include? "dirty"
    end

    def distclean
        `make distclean`
    end

    def generateQMake(qmake)
        `#{qmake} \"CONFIG*=debug_and_release debug_and_release_target build_all\"`
    end

    def compile()
        puts "Compiling Library"
        system("make all -j4")
    end

    def createKit()
        puts "Creating Kit #{@library_home}" 
        Dir.chdir(@library_home)
        `find #{Dir.pwd} -name \"*tar.gz\" -exec rm \{\} \\;`    
        `find #{Dir.pwd} -name \"createKit.sh\" -exec \{\} \\; &` 
    end

    def install(destination)
        kits = `find #{Dir.pwd} -name \"*tar.gz\"`
        puts "KIT FOUND #{kits}"

        kits.split.each do |k|
            current_dir = Dir.pwd
             Dir.chdir(destination)
            `tar xzf #{k}`
            Dir.chdir(current_dir)
        end
        
    end

    def build(settings, distClean = false)
        if distClean
            puts "I'am in #{Dir.pwd}"
            self.distclean
        end

        puts "Generating QMAKE"
        self.generateQMake(settings.qmake)
        self.compile
        self.createKit
    end
end

class EltIpcCompiler < LibraryCompiler
    def initialize(libraryDirectory)
        @library_home = libraryDirectory
        @amqp_dir = File.expand_path("qamqp/src", @library_home)
        proFile = `find -name \"Ipc.pro\"`
        @ipc_pro = File.dirname(proFile) 
        Dir.chdir(@library_home)
        @describe = `git describe --long --dirty`
    end
    
    def compileAmqp(qmake)
        Dir.chdir(@amqp_dir)
        system("make distclean")
        `#{qmake} \"src\.pro\" \"CONFIG+=debug_and_release QAMQP_LIBRARY_TYPE=staticlib\"`
        system("make all -j4")
        `find -name \".qmake.stash\" -exec rm \{\} \\;`
    end

    def generateQMake(qmake)
        compileAmqp(qmake)
        Dir.chdir(@ipc_pro)
        `#{qmake} \"CONFIG+=debug_and_release\"`
    end
end


class LibraryDeployer
    attr_reader :libs
    def initialize(configurationFile)
        @settings = Settings.new(configurationFile)
        @libs = @settings.configuration.keys.select{|key| not(key.include? "qmake" or key.include? "Resources")}
    end
    
    
    def removeLibraries(libraryList)
        Dir.chdir(File.expand_path(@settings.extResources()))

        libraryList.each do |lib|
            if(File.directory?(File.expand_path(lib, Dir.pwd))) 
                puts "Removing #{lib}"
                FileUtils.remove_dir(lib)
            else
                puts "Library #{lib} not found"
            end 
        end
    end

    def deploy(distClean = false)
        #eltIpc
        eltIpc = EltIpcCompiler.new(@settings.eltIpc)
        eltIpc.build(@settings, distClean)
        eltIpc.install(@settings.extResources)

        #eltGraphs
        eltGraphs = LibraryCompiler.new(@settings.eltGraphs)
        eltGraphs.build(@settings, distClean)
        eltElintGraphsExtResources = File.expand_path("ELT_ELINT_GRAPHS_LIB/ext_resources", @settings.eltElintGraphs)
        #eltGraphs.install(eltElintGraphsExtResources)
        eltGraphs.install(@settings.extResources)
        
        #eltElintGraphs
        eltElintGraphs = LibraryCompiler.new(@settings.eltElintGraphs)
        eltElintGraphs.build(@settings, distClean)
        eltElintGraphs.install(@settings.extResources)

        #hmiCommon
        hmiCommon = LibraryCompiler.new(@settings.hmiCommon)
        hmiCommon.build(@settings, distClean)
        hmiCommon.install(@settings.extResources)

        #hmiInterface
        hmiInterface = LibraryCompiler.new(@settings.hmiInterface)
        hmiInterface.build(@settings, distClean)
        hmiInterface.install(@settings.extResources)
    end
end

deployer = LibraryDeployer.new("./libraryBuilder.ini")
libraryToRemove = deployer.libs
libraryToRemove << "hmiCommonCore" << "hmiCommonGui"
deployer.removeLibraries(libraryToRemove)
deployer.deploy(true)

