require "sqlite3"

class File
  def each_chunk(chunk_size=1024*1024)
    yield read(chunk_size) until eof?
  end
end

class Graph
  HEADER_SIZE = 4
  def initialize(f,db_path, dbg = true)
    @debug = dbg
    debug "loading file"
    @d = []
    f.each_chunk do |chunk|
      @d.concat(chunk.unpack("L*"))
    end
    @db = SQLite3::Database.new db_path
  end

  def at(p,i)
    @d[p/4+i]
  end

  def link_count(p)
    at(p,1)
  end

  def bi_link_count(p)
    at(p,2)
  end

  def meta(p)
    at(p,3)
  end

  def page_links(p)
    x = p/4
    c = @d[x+1] # link count
    @d[x+HEADER_SIZE..x+HEADER_SIZE+c-1]
  end

  def page_bi_links(p)
    x = p/4
    c = @d[x+2] # bi link count
    @d[x+HEADER_SIZE..x+HEADER_SIZE+c-1]
  end

  def page_un_links(p)
    x = p/4
    b = @d[x+2] # bi link count
    c = @d[x+1] # bi link count
    @d[x+HEADER_SIZE+b..x+HEADER_SIZE+c-1]
  end

  def name(p)
    rs = @db.execute("SELECT title FROM pages WHERE offset = ? LIMIT 1",p)
    return nil if rs.empty?
    rs.first.first
  end

  def find(s)
    rs = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1",s)
    return nil if rs.empty?
    rs.first.first
  end

  private

  def debug(msg)
    STDERR.puts msg if @debug
  end
end
