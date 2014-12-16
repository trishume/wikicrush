# Comment out filters you don't want
def filter(title)
  return false if title.include?(':')
  # return false if title.include?('List of ')
  true
end


def read_file(name,out)
  IO.foreach(name) do |line|
    title = line.chomp.split('|').first
    out.puts title if filter(title)
  end
end

out = File.open("titles.txt",'w')
puts "Parsing links"
read_file("links.txt",out)
puts "Parsing redirects"
read_file("redirects.txt",out)
out.close
