require_relative "graph.rb"

def print_list(g,ls)
  p ls.map { |l| g.name(l) }
end

raise "Usage: inspect.rb path/to/index.bin path/to/xindex.db query" unless ARGV.length == 3

f = File.open(ARGV[0])
g = Graph.new(f,ARGV[1])

query = ARGV[2].strip
if query.to_i.to_s == query
  q = query.to_i
else
  q = g.find(query)
end
raise "Could not find page" unless q

puts "Name: #{g.name(q)}"
puts "Index: #{q}"
puts "Meta: #{g.meta(q).to_s(2).rjust(32,'0')}"
puts "Link Count: #{g.link_count(q)}"
puts "Bidirectional Links: #{g.bi_link_count(q)}"
puts "Bidirectional Links:"
print_list(g, g.page_bi_links(q))
links = g.page_links(q)
puts "Outgoing Link Offsets:"
p links
puts "Outgoing Links:"
print_list(g, links)
