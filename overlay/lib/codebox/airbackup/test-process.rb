#!/usr/bin/env ruby

$stdout.puts("on STDOUT plop")
$stderr.puts("on STDERR prout")
$stdout.puts("on STDOUT plop")
sleep 2

$stderr.puts("on STDERR prout")
$stdout.puts("on STDOUT plop")
$stderr.puts("on STDERR prout")

exit 1

