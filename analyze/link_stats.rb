require "triez"

raise "Usage: ruby link_stats.rb path/to/links.txt path/to/titles.txt" unless ARGV.length == 2
links_path, titles_path = ARGV

puts "Building Validity Hash"
valid = Triez.new value_type: :object
IO.foreach(titles_path) do |l|
  valid[l.strip] = true
end

puts "Analyzing Links"
stats = Hash.new(0)
IO.foreach(links_path) do |line|
  page, *links = line.chomp.split('|').map{ |x| x.strip }
  stats[:pages] += 1
  p [page,links,line] unless page
  if valid.has_key?(page)
    stats[:valid_pages] += 1
    stats[:links] += links.count

    links_uniq = links.uniq
    stats[:unique_links] += links_uniq.count
    stats[:valid_links] += links_uniq.count { |l| valid.has_key?(l)}
  end
end
stats[:valid_link_frac] = stats[:valid_links] / stats[:unique_links].to_f
stats[:valid_page_frac] = stats[:valid_pages] / stats[:pages].to_f
[:links,:unique_links,:valid_links].each do |stat|
  avg_name = ("average_" + stat.to_s).intern
  stats[avg_name] = stats[stat] / stats[:valid_pages].to_f
end
p stats
