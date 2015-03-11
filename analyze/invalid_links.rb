require "triez"

raise "Usage: ruby invalid_links.rb path/to/links.txt path/to/titles.txt max" unless ARGV.length == 3
links_path, titles_path, max = ARGV
MAX_PAGES = max.to_i

STDERR.puts "Building Validity Hash"
valid = Triez.new value_type: :object
IO.foreach(titles_path) do |l|
  valid[l.strip] = true
end

STDERR.puts "Analyzing Links"
count = 0
IO.foreach(links_path) do |line|
  page, *links = line.chomp.split('|').map{ |x| x.strip }
  invalid = links.uniq.reject { |l| valid.has_key?(l)}
  puts "# #{page}"
  invalid.each { |x| puts x }
  count += 1
  break if count > MAX_PAGES
end
