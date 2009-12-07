#!/usr/bin/env ruby

require 'rubygems'
require 'systemu'
require File.dirname(__FILE__) + "/../commons.rb"


def colorize(text, color_code)
    "#{color_code}#{text}\033[0m"
end

def gray(text); colorize(text, "\033[1;30;40m"); end
def cyan(text); colorize(text, "\033[1;36;40m"); end
def red(text); colorize(text, "\033[31m"); end
def green(text); colorize(text, "\033[32m"); end

cmd = %q(sleep 5)

cmd = %q(./test-process.rb)
verbose = false

Codebox::Out.debug("Running: #{cmd}")
status, stdout, stderr = systemu cmd do |cid|
    while true do
        sleep 1
        STDERR.print "."
        STDERR.flush
    end
end
STDERR.puts
if (verbose or status.exitstatus != 0)
    Codebox::Out.info("Process exited successfully") if status.exitstatus == 0
    Codebox::Out.error("Process exited with error: #{status.exitstatus}") if status.exitstatus != 0
    if stdout && stdout.length > 0
        stdout.each do |line|
            line.strip!
            Codebox::Out.debug("STDOUT: #{line}") unless line.empty?
        end
    end
    if stderr && stderr.length > 0
        stderr.each do |line|
            line.strip!
            Codebox::Out.warn("STDERR: #{line}") unless line.empty?
        end
    end
end

