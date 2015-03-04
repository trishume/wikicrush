require "sqlite3"
require "triez"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3
  attr_accessor :pos

  def initialize(f,redirs,db_path,bin_path)
    @redirects = redirs
    @f = f
    @db = SQLite3::Database.new db_path
    @out = File.open(bin_path,"w")
    @fails = 0
    file_header
  end

  def document
    IO.foreach(@f).with_index do |l,i|
      page(l.chomp.split('|').map{ |x| x.strip })
      if i % 5000 == 0
        puts "#{(i/@total.to_f*100.0).round(3)}%"
      end
    end
    puts "Fails: #{@fails}"
    @out.close
  end

  def page(line)
    fill(line.shift, line)
  end

  def file_header
    @total = @db.execute("SELECT count(*) FROM pages").first.first
    # version, num articles, header length, extra
    @out.write([1,@total,FILE_HEADER_SIZE,0].pack("L*"))
  end

  def fill(title, ls)
    offset, link_count = @db.execute("SELECT offset,linkcount FROM pages WHERE title = ? LIMIT 1", title).first
    link_data = ls.uniq.map{ |l| get_offset(l)}.compact
    @out.write([0,link_count,0].pack("LLL")) # header
    # Ensure correct number of links is written
    if link_data.length < link_count
      puts "Fail on #{title} #{link_count} != #{link_data.length}"
      link_data += [offset] * (link_count - link_data.length)
      @fails += 1
    end
    @out.write(link_data.pack("L*"))
  end

  private

  def get_offset(name)
    name = name.capitalize
    name = @redirects[name] || name
    rows = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1", name)
    return nil if rows.empty?
    rows.first.first
  end
end

die "Usage: ruby 4-binindex.rb path/to/links.txt path/to/redirects.txt path/to/xindex.db path/to/put/index.bin" unless ARGV.length == 4
links_path, redirs_path, db_path, bin_path = ARGV

puts "Building Redirect Hash"
redirects = Triez.new value_type: :object
IO.foreach(redirs_path) do |l|
  key,val = l.chomp.split('|').map{ |x| x.strip }
  redirects[key] = val
end

f = File.open(links_path)
p = Parser.new(f,redirects,db_path, bin_path)
p.document
