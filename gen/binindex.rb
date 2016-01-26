require "sqlite3"
require "triez"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3
  attr_accessor :pos

  def initialize(f,db_path,bin_path)
    @f = f
    @db = SQLite3::Database.new db_path
    @out = File.open(bin_path,"w")
    file_header
  end

  def document
    IO.foreach(@f).with_index do |l,i|
      page(l.chomp.split('|'))
      if i % 10_000 == 0
        puts "#{(i/@total.to_f*100.0).round(3)}%"
      end
    end
    @out.close
  end

  def page(line)
    name, meta, *links = line
    fill(name, meta, links)
  end

  def file_header
    @total = @db.execute("SELECT count(*) FROM pages").first.first
    # version, num articles, header length, extra
    @out.write([1,@total,FILE_HEADER_SIZE,0].pack("L*"))
  end

  def fill(title, meta, ls)
    link_data = ls.map{ |l| get_offset(l)}
    @out.write([0,link_data.length,0].pack("LLL")) # header
    @out.write(link_data.pack("L*"))
  end

  private

  def get_offset(name)
    rows = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1", name)
    rows.first.first
  end
end

raise "Usage: ruby binindex.rb path/to/links.txt path/to/xindex.db path/to/put/index.bin" unless ARGV.length == 3
links_path, db_path, bin_path = ARGV

f = File.open(links_path)
p = Parser.new(f,db_path, bin_path)
p.document
