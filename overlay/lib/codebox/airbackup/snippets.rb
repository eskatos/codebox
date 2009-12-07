#!/usr/bin/env ruby

require 'pty'

begin
    PTY.spawn( "ps ax" ) do |stdin, stdout, pid|
        begin
            stdin.each { |line|
                print line }
        rescue Errno::EIO
        end
    end
rescue PTY::ChildExited
    puts "The child process exited!"
end
