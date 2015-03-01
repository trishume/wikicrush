require "sqlite3"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3
  attr_accessor :pos

  def initialize(f,redirs)
    @redirects = redirs
    @f = f
    @db = SQLite3::Database.new "xindex.db"
    @out = File.open("index.bin","w")
    @fails = 0
    file_header
  end

  def document
    IO.foreach(@f).with_index do |l,i|
      page(l.chomp.split('|'))
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
      link_data += [offset] * (link_count - link_data.length)
      puts "Fail on #{title} #{link_count} != #{link_data.length}"
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

puts "Building Redirect Hash"
redirects = {}
IO.foreach("redirects.txt") do |l|
  key,val = l.chomp.split('|')
  redirects[key] = val
end

f = File.open("links.txt")
p = Parser.new(f,redirects)
p.document
