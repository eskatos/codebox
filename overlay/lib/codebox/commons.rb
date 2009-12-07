#!/usr/bin/env ruby

require 'date'
require 'rubygems'
require 'systemu'

module Codebox
    
    VERSION = "0.1.0"

    module Out
        def error(msg)
            puts build('ERROR', msg, RED)
        end
        def warn(msg)
            puts build('WARNING', msg, YELLOW)
        end
        def info(msg)
            puts build('INFO', msg, WHITE)
        end
        def debug(msg)
            puts build('DEBUG', msg, GRAY)
        end
        def input(msg)
            print build('INPUT', msg, GREEN)
            gets.chomp
        end
        :private
        RED           = "\033[1;31;40m"
        GREEN         = "\033[1;32;40m"
        YELLOW        = "\033[1;33;40m"
        WHITE         = "\033[1;37;40m"
        GRAY          = "\033[1;30;40m"
        LEVEL_MAX_LEN = 7
        def build(level, msg, color_code)
            DateTime.now.to_s + ' [ ' + colorize(level[0..(LEVEL_MAX_LEN-1)].center(LEVEL_MAX_LEN), color_code) + ' ] ' + colorize(msg, color_code)
        end
        def colorize(msg, color_code)
            "#{color_code}#{msg}\033[0m"
        end
    end

    module System
        include Codebox::Out
        def execute(cmd, verbose=false)
            debug("Running: #{cmd}")
            status, stdout, stderr = systemu cmd do |child_pid|
                while true do
                    sleep 1
                    STDERR.print "."
                    STDERR.flush
                end
            end
            STDERR.puts
            if (verbose or status.exitstatus != 0)
                info("Process exited successfully") if status.exitstatus == 0
                error("Process exited with error: #{status.exitstatus}") if status.exitstatus != 0
                if stdout && stdout.length > 0
                    stdout.each do |line|
                        line.strip!
                        debug("STDOUT: #{line}") unless line.empty?
                    end
                end
                if stderr && stderr.length > 0
                    stderr.each do |line|
                        line.strip!
                        warn("STDERR: #{line}") unless line.empty?
                    end
                end
                raise "Process exited with error: #{status.exitstatus}" if status.exitstatus != 0
            end
        end
        def running_on_debian
            File.exists?('/etc/debian_version')
        end
        # Returns an array containing major, minox and fix versions numbers
        def debian_version
            IO.read('/etc/debian_version').strip.split('.')
        end
    end

end


# Usage example
if $0 == __FILE__


    include Codebox::Out
    include Codebox::System

    info("Wow an info output")
    debug("Wow a debug output")
    warn("Wow a warning output")
    error("Wow an error output")

    puts
    puts debian_version[0]
    puts debian_version[1]

end
