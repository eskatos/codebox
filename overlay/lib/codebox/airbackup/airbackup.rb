#!/usr/bin/env ruby

require 'rubygems'
require 'date'
require 'fileutils'
require 'systemu'
require File.dirname(__FILE__) + "/../commons.rb"
require File.dirname(__FILE__) + "/../config/ini-files.rb"


# AirBackup:: a pico framework to manage backups.
#
# Contains two implementations for now :
#  - DuplicityBackup that use duplicity for incremental filesystem backup
#  - MysqlBackup that use mysqldump for full database backup
#
module AirBackup

    VERSION = Codebox::VERSION

    @@verbose = false
    def AirBackup.verbose(verb = @@verbose)
        @@verbose = verb
    end

    # The Backup contract and mixin that shall be included by all Backup implementations.
    module Backup
        include Codebox::System
        include Codebox::Out

        # state
        attr_reader :name,:source,:target
        def initialize(name,source,target)
            @name = name
            @source = source
            @target = target
        end

        # behaviour
        def collection_status() raise "collection_status() must be overridden";end
        def backup() raise "backup() must be overridden";end
        def force_full_backup() raise "force_full_backup() must be overridden";end
        def remove_older_than(days) raise "remove_older_than(days) must be overridden";end
        def quick_restore() raise "quick_restore() must be overridden";end

    end


    # Incremental files backup using duplicity
    # See http://duplicity.nongnu.org/ for details
    class DuplicityBackup
        include Backup
        def collection_status
            info("#{@name}.collection_status")
            execute("duplicity verify -v5 --no-encryption \"#{@target}/dirs/#{@name}\" \"#{@source}\"", AirBackup::verbose)
            execute("duplicity collection-status \"#{@target}/dirs/#{@name}\"", AirBackup::verbose)
        end
        def backup
            info("#{@name}.backup")
            execute("duplicity --no-encryption \"#{@source}\" \"#{@target}/dirs/#{@name}\"", AirBackup::verbose)
        end
        def force_full_backup
            info("#{@name}.force_full_backup")
            execute("duplicity full --no-encryption \"#{@source}\" \"#{@target}/dirs/#{@name}\"", AirBackup::verbose)
        end
        def remove_older_than(days)
            info("#{@name}.remove_older_than(#{days})")
            execute("duplicity remove-older-than #{days}D --force --no-encryption \"#{@target}/dirs/#{@name}\"", AirBackup::verbose)
        end
        def quick_restore
            info("#{@name}.quick_restore")
            execute("duplicity restore --no-encryption --force \"#{@target}/dirs/#{@name}\" \"#{@source}\"", AirBackup::verbose)
        end
    end


    # Full mysql backup dump using mysqldump
    # TODO Implement history browsing and restore
    class MysqlBackup
        include Backup
        attr_reader :local
        attr_writer :local
        def collection_status
            execute("find #{@local}/#{@name} | sort", AirBackup::verbose)
        end
        def backup
            info("#{@name}.backup")
            do_backup
        end
        def force_full_backup
            info("#{@name}.force_full_backup")
            do_backup
        end
        def remove_older_than(days)
            info("#{@name}.remove_older_than(#{days})")
            warn("MysqlBackup.remove_older_than(days) is NOT IMPLEMENTED YET")
        end
        def quick_restore
            info("#{@name}.quick_restore")
            execute("zcat \"#{last_available_backup}\" | mysql -u root -proot -h localhost \"#{@source}\"", AirBackup::verbose)
        end
        :private
        def do_backup
            FileUtils.mkdir_p("#{@local}/#{@name}")
            execute("mysqldump -u root -proot -h localhost \"#{@source}\" | gzip > \"#{gen_local_full_path(DateTime.now)}\"", AirBackup::verbose)
            execute("duplicity --no-encryption \"#{@local}/#{@name}\" \"#{@target}/mysql/#{@name}\"", AirBackup::verbose)
        end
        def gen_local_full_path(datetime)
            "#{@local}/#{@name}/#{@name}-mysqldump_#{datetime.to_s}.gz"
        end
        def last_available_backup
            available_backups = []
            Dir["#{@target}/*.gz"].each do |path| available_backups << path; end
            available_backups.sort! { |a,b| extract_datetime(a) <=> extract_datetime(b) }
            available_backups[-1]
        end
        def extract_datetime(filename)
            reg = /#{@name}-mysqldump_(.*)\.gz/
            date = filename.scan(reg)[0][0]
            DateTime.parse(date)
        end
    end


    # BackupRepository loads the AirBackup config file and instanciate Backup implementations accordingly.
    class BackupRepository
        include Codebox::Out
        def initialize(config_path)
            info("Codebox AirBackup #{AirBackup::VERSION}") if AirBackup::verbose
            ensure_dependencies
            @all = []
            conf = IniFile.new(config_path, true)
            debug("Loaded configuration from '#{config_path}'") if AirBackup::verbose
            url = conf['backup']['url'].value
            mysql_local = conf['backup']['mysql-local'].value
            conf.each_key do |section_name|
                next if section_name == "backup"
                if conf[section_name]['type'].value == "dir"
                    dirpath = conf[section_name]['dir'].value
                    debug("Loaded directory backup '#{section_name}'") if AirBackup::verbose
                    @all << DuplicityBackup.new(section_name,dirpath,url)
                elsif conf[section_name]['type'].value == "mysql"
                    dbname = conf[section_name]['dbname'].value
                    my_backup = MysqlBackup.new(section_name,dbname,url)
                    my_backup.local = mysql_local
                    debug("Loaded mysql backup '#{section_name}'") if AirBackup::verbose
                    @all << my_backup
                end
            end
        end
        def each
            @all.each do |backup|
                yield backup
            end
        end
        def [](key)
            @all.each do |backup|
                return backup if backup.name == key
            end
            return nil
        end
        def ensure_dependencies
            deps = [ 'duplicity', 'mysqldump' ]
            debug("Ensuring all mandatory dependencies are installed: #{deps.inspect}") if AirBackup::verbose
            ENV['PATH'].split(':').each do |path|
                deps.each do |dep|
                    candidate = path + '/' + dep
                    deps.delete(dep) if  File.exists?(candidate) && File.executable?(candidate)
                end
            end
            unless deps.empty?
                error("Mandatory executables were not found on your system, cannot continue: #{deps.inspect}")
                exit 1
            end
        end
    end

end


# Usage example
if $0 == __FILE__

    AirBackup.verbose(true)

    #backup_repos = AirBackup::BackupRepository.new(File.dirname(__FILE__) + "/test-codebox.conf")
    backup_repos = AirBackup::BackupRepository.new(File.dirname(__FILE__) + "/test-eskatos.conf")

    backup_repos.each do |backup|
        backup.force_full_backup
        backup.backup
        backup.remove_older_than(42)
        backup.quick_restore
        backup.collection_status
        puts
        puts
    end

    #    b = backup_repos["db-test"]
    #    b.backup
    #b.quick_restore
    
end

