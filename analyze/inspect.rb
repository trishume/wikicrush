require_relative "graph.rb"

def print_list(g,ls)
  p ls.map { |l| g.name(l) }
end

die "Usage: inspect.rb path/to/index.bin path/to/xindex.db query" unless ARGV.length == 3

f = File.open(ARGV[0])
g = Graph.new(f,ARGV[1])
q = g.find(ARGV[2])
die "Could not find page" unless q

puts "Name: #{g.name(q)}"
puts "Link Count: #{g.link_count(q)}"
puts "Bidirectional Links: #{g.bi_link_count(q)}"
puts "Bidirectional Links:"
print_list(g, g.page_bi_links(q))
puts "Outgoing Links:"
print_list(g, g.page_un_links(q))
