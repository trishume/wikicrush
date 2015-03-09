require "triez"

raise "Usage: ruby casenorm.rb path/to/links-filtered.txt path/to/put/links.txt" unless ARGV.length == 2
links_path,out_path = ARGV
SEP = '|'

valid = Triez.new value_type: :object

STDERR.puts "Processing links:"
count = 0
out = File.open(out_path,"w")
IO.foreach(links_path) do |line|
  page, *links = line.chomp.split('|').map{ |x| x.strip.downcase }
  next if valid.has_key?(page)
  valid[page] = true

  out.print page
  out.print SEP
  out.puts links.uniq.join(SEP)

  count += 1
  print '.' if count % 10000 == 0
end
