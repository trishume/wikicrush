require "triez"

raise "Usage: ruby proclinks.rb path/to/titles.txt path/to/redirects.txt path/to/links.txt path/to/put/links.txt" unless ARGV.length == 4
titles_path, redir_path, links_path, out_path = ARGV

puts "Building Validity Hash"
valid = Triez.new value_type: :object
IO.foreach(titles_path) do |l|
  valid[l.chomp] = true
end
puts "Building Redirect Hash"
redirects = Triez.new value_type: :object
IO.foreach(redir_path) do |l|
  key,val = l.chomp.split('|')
  redirects[key] = val
end

puts "Processing..."
out = File.open(out_path,'w')
IO.foreach(links_path) do |l|
  page,meta,*links = l.split('|').map { |x| x.strip }
  # next if page.length == 0
  links.reject! { |li| li.length == 0 }
  links.each do |li|
    li[0] = li[0].capitalize
  end
  links.map! { |li| redirects[li] || li }
  links = links.select { |li| valid.has_key?(li) }.uniq
  links.unshift(page,meta)
  out.puts links.join('|')
end
out.close
