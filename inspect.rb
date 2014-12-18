require_relative "graph.rb"

def print_list(g,ls)
  p ls.map { |l| g.name(l) }
end

f = File.open("newindex.bin")
g = Graph.new(f)
q = g.find(ARGV[0] || "North Pole")

puts "Name: #{g.name(q)}"
puts "Link Count: #{g.link_count(q)}"
puts "Bidirectional Links: #{g.bi_link_count(q)}"
puts "Bidirectional Links:"
print_list(g, g.page_bi_links(q))
puts "Outgoing Links:"
print_list(g, g.page_un_links(q))
