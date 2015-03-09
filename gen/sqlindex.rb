require "sqlite3"
require "fileutils"
require "triez"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3
  attr_accessor :pos

  def initialize(f,valid,db_path)
    @f = f
    @valid = valid
    @pos = FILE_HEADER_SIZE
    @total = 0

    FileUtils.rm_f(db_path)
    @db = SQLite3::Database.new db_path
    @db.execute <<-SQL
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int,
  linkcount int
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
      page(l.chomp.split('|').map{ |x| x.strip })
      print '.' if i % 1000 == 0
    end
  end

  def page(line)
    name = line.shift
    l = filter_links(line)
    @db.execute("INSERT INTO pages (title, offset, linkcount) VALUES (?,?,?)",[name,@pos,l])
    @pos += HEADER_SIZE + LINK_SIZE*l
    @total += 1
  end

  def filter_links(ls)
    ls.uniq.count { |l| @valid.has_key?(l.capitalize)}
  end
end

raise "Usage: ruby 3-sqlindex.rb path/to/links.txt path/to/titles.txt path/to/put/xindex.db" unless ARGV.length == 3
links_path, titles_path, db_path = ARGV

puts "Building Validity Hash"
valid = Triez.new value_type: :object
IO.foreach(titles_path) do |l|
  valid[l.strip] = true
end

puts "Parsing"
f = File.open(links_path)
# f = STDIN
p = Parser.new(f,valid,db_path)
p.document
p.finish
