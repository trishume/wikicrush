require "sqlite3"
require "fileutils"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3
  attr_accessor :pos

  def initialize(f,valid)
    @f = f
    @valid = valid
    @pos = FILE_HEADER_SIZE
    @total = 0

    FileUtils.rm_f("xindex.db")
    @db = SQLite3::Database.new "xindex.db"
    @db.execute <<-SQL
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int
);
SQL
    @db.execute("CREATE INDEX pages_offset ON pages (offset)")
    @db.execute("PRAGMA synchronous = OFF;")
  end

  def finish
    @db.execute("PRAGMA synchronous = ON;")
    puts "Number of Pages: #{@total}"
    puts "File size: #{@pos}"
  end

  def document
    IO.foreach(@f).with_index do |l,i|
      page(l.chomp.split('|'))
      print '.' if i % 1000 == 0
    end
  end

  def page(line)
    name = line.shift
    l = filter_links(line)
    @db.execute("INSERT INTO pages (title, offset) VALUES (?,?)",[name,@pos])
    @pos += HEADER_SIZE + LINK_SIZE*l
    @total += 1
  end

  def filter_links(ls)
    ls.uniq.select { |l| @valid[l.capitalize]}.length
  end
end

puts "Building Validitity Hash"
valid = {}
IO.foreach("titles.txt") do |l|
  valid[l.chomp] = true
end

puts "Parsing"
f = File.open("links.txt")
# f = STDIN
p = Parser.new(f,valid)
p.document
p.finish
