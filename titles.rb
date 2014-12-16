# Comment out filters you don't want
def filter(title)
  return false if title.start_with?('Category:')
  return false if title.start_with?('File:')
  return false if title.start_with?('Wikipedia:')
  return false if title.start_with?('Template:')
  # return false if title.include?('List of ')
  true
end

$valid = {}
# redirects checks to see if a redirect points to a valid article and only includes it if it does
def read_file(name,out,redirects = false)
  IO.foreach(name) do |line|
    title,redir = line.chomp.split('|')[0..1]
    next if redirects && !$valid[redir]
    out.puts title if filter(title)
    $valid[title] = true
  end
end

out = File.open("titles.txt",'w')
puts "Parsing links"
read_file("links.txt",out)
puts "Parsing redirects"
read_file("redirects.txt",out,true)
out.close
