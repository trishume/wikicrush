require "sqlite3"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*2
  attr_accessor :pos

  def initialize(f,valid)
    @f = f
    @valid = valid
    @pos = FILE_HEADER_SIZE

    @db = SQLite3::Database.new "xindex.db"
    @db.execute <<-SQL
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int
);
SQL
    @db.execute("PRAGMA synchronous = OFF;")
  end

  def finish
    @db.execute("PRAGMA synchronous = ON;")
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
      print '.' if count % 1000 == 0
    end
  end

  def page
    match("<t>")
    name = @f.gets("<")[0..-2] # title
    match("/t>")
    l = links
    match(">") # only thing left over after <l> tries to consume </p>
    @db.execute("INSERT INTO pages (title, offset) VALUES (?,?)",[name,@pos])
    @pos += HEADER_SIZE + LINK_SIZE*l
  end

  def links
    ls = []
    while @f.read(3) == "<l>"
      name = @f.gets("<")[0..-2].capitalize
      ls << name if @valid[name]
      match("/l>")
    end
    ls.uniq.length
  end

  def page_at(i)
    @f.seek(i)
    match("<p>")
    page
  end

  private

  def match(s)
    x = @f.read(s.length)
    raise "got #{x} expected #{s}" unless x == s
  end
end

puts "Building Validitity Hash"
valid = {}
IO.foreach("titles.txt") do |l|
  valid[l.chomp] = true
end

puts "Parsing"
f = File.open("/Users/tristan/misc/simplewiki-links.xml")
# f = STDIN
p = Parser.new(f,valid)
if ARGV.length > 0
  p.page_at(ARGV.first.to_i)
else
  p.header
  p.document
  p.finish
  puts "File size: #{p.pos}"
end
