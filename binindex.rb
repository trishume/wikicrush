require "sqlite3"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*2
  attr_accessor :pos

  def initialize(f)
    @f = f
    @db = SQLite3::Database.new "xindex.db"
    @out = File.open("index.bin","w")
    file_header
  end

  def header
    # @f.seek(38)
    @f.read(38)
  end

  def document
    match("<d>")
    count = 0
    while @f.read(3) == "<p>"
      page
      count += 1
      if count % 5000 == 0
        puts "#{(count/@total.to_f*100.0).round(3)}%"
      end
    end
    @out.close
  end

  def page
    match("<t>")
    @f.gets("<") # title
    match("/t>")
    l = links
    match(">") # only thing left over after <l> tries to consume </p>
    fill(l)
  end

  def links
    ls = []
    while @f.read(3) == "<l>"
      ls << @f.gets("<")[0..-2]
      match("/l>")
    end
    ls
  end

  def file_header
    @total = @db.execute("SELECT count(*) FROM pages").first.first
    # version, num articles, header length, extra
    @out.write([1,@total,FILE_HEADER_SIZE,0].pack("L*"))
  end

  def fill(ls)
    @out.write([0,ls.length].pack("LL")) # header
    link_data = ls.map{ |l| get_offset(l)}.compact.uniq.pack("L*")
    @out.write(link_data)
  end

  private

  def match(s)
    x = @f.read(s.length)
    raise "got #{x} expected #{s}" unless x == s
  end

  def get_offset(name)
    rows = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1", name.capitalize)
    return nil if rows.empty?
    rows.first.first
  end
end

f = File.open("/Users/tristan/misc/simplewiki-links.xml")
# f = STDIN
p = Parser.new(f)
p.header
p.document
