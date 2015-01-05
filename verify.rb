require "progress"
require "sqlite3"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3

  def initialize(f)
    @f = f
    @db = SQLite3::Database.new "xindex.db"
  end

  def run
    header = @f.read(FILE_HEADER_SIZE)
    num_pages = header.unpack("LLLL")[1]
    puts "Processing #{num_pages} pages."
    num_pages.times.with_progress do
      do_page
    end
  end

  def do_page
    this_page = @f.pos
    die "Header fail at #{this_page}" unless get_int == 0
    die "No entry in page DB for #{this_page}" unless name(this_page)
    num_links = get_int
    die "Already processed" unless get_int == 0
    @f.read(4*num_links)
    # (1..num_links).map {get_int}
  end

  private

  def get_int
    @f.read(4).unpack("L").first
  end

  def name(p)
    rs = @db.execute("SELECT title FROM pages WHERE offset = ? LIMIT 1",p)
    return nil if rs.empty?
    # rs.first.first
    true
  end

  def die(msg)
    puts msg
    exit(1)
  end
end

f = File.open("index.bin")
p = Parser.new(f)
p.run
