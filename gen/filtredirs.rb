require "triez"

raise "Usage: ruby filtredirs.rb path/to/titles.txt path/to/redirects.txt path/to/put/redirects-filt.txt" unless ARGV.length == 3
titles_path, redir_path, out_path = ARGV

puts "Building Validity Hash"
valid = Triez.new value_type: :object
IO.foreach(titles_path) do |l|
  valid[l.chomp] = true
end

puts "Processing..."
out = File.open(out_path,'w')
IO.foreach(redir_path) do |l|
  from,to = l.split('|').map { |x| x.strip }
  # This doesn't do anything, everything is capped
  # to[0] = to[0].capitalize
  next unless valid.has_key?(to) # points to valid thing
  next if valid.has_key?(from) # conflicts with real page
  out.puts "#{from}|#{to}"
end
out.close
