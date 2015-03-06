# Comment out filters you don't want
def filter(title)
  # return false if title.start_with?('Category:')
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
    title,redir = line.chomp.split('|')[0..1].map{ |x|x.strip }
    next if redirects && !$valid[redir]
    out.puts title if filter(title)
    $valid[title] = true
  end
end

die "Usage: ruby 2-titles.rb path/to/links.txt path/to/redirects.txt path/to/put/titles.txt" unless ARGV.length == 3
links_path, redir_path, titles_path = ARGV
out = File.open(titles_path,'w')
puts "Parsing links"
read_file(links_path,out)
puts "Parsing redirects"
read_file(redir_path,out,true)
out.close
