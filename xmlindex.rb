require "sqlite3"

class Parser
  def initialize(f)
    @f = f
    @db = SQLite3::Database.new "xindex.db"
    @db.execute <<-SQL
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int,
  links int
) WITHOUT ROWID;
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
    loc = @f.pos - 3
    match("<t>")
    name = @f.gets("<")[0..-2] # title
    match("/t>")
    l = links
    match(">") # only thing left over after <l> tries to consume </p>
    @db.execute("INSERT INTO pages (title, offset, links) VALUES (?,?,?)",[name,loc,l])
  end

  def links
    count = 0
    while @f.read(3) == "<l>"
      count += 1
      @f.gets("<")
      match("/l>")
    end
    count
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

f = File.open("/Users/tristan/misc/simplewiki-links.xml")
# f = STDIN
p = Parser.new(f)
if ARGV.length > 0
  p.page_at(ARGV.first.to_i)
else
  p.header
  p.document
end
