require "sqlite3"
require "triez"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*4
  NAMESPACES = {"Category" => 1, "Wikipedia" => 2, "Portal" => 3, "Book" => 4}
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
    @out.write([2,@total,FILE_HEADER_SIZE,HEADER_SIZE].pack("L*"))
  end

  def fill(title, meta, ls)
    link_data = ls.map{ |l| get_offset(l)}
    @out.write([0,link_data.length,0, meta_bits(title, meta)].pack("LLLL")) # header
    @out.write(link_data.pack("L*"))
  end

  private

  def get_offset(name)
    rows = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1", name)
    rows.first.first
  end

  # 32 bits of metadata, packed like so (starting at the least significant bit):
  #
  # 3 bits = log10(length of article markup in bytes)
  # 4 bits = min(number of words in title, 15)
  # 1 bit = 1 if is a disambiguation page
  #
  # 3 bits = article namespace of [normal, category, wikipedia, portal, book ... potential others ... 7=other namespace]
  # 1 bit = 1 if page is a "List of" article
  # 1 bit = 1 if page is a year
  # The following bits are not set by this script but their places are reserved
  # 1 bit = if the article is a featured article
  # 1 bit = if the article is a "good" article
  # (32-15=17) bits of zeroes reserved for future use
  def meta_bits(name, meta)
    textlen_str, flags = meta.split('-')
    log_textlen = textlen_str.length - 1 # should be log10(textlen)
    raise "Out of range textlen" if log_textlen > 7 || log_textlen < 0
    title_words = [name.split.length,15].min

    if /^([A-Z][a-z]+):/ =~ name
      type = NAMESPACES[$1] || 7
    else
      type = 0
    end

    is_disambig = (!!flags) && flags.include?('D')
    is_list = name.start_with?("List of ")
    is_year = (/^[0-9]{1,4}$/ === name)

    pack_bits([[log_textlen, 3], [title_words, 2], [is_disambig, 1], [type, 3], [is_list, 1], [is_year, 1]])
  end

  def pack_bits(arr)
    res = 0
    bits_so_far = 0
    arr.each do |n, num_bits|
      n = 1 if n == true
      n = 0 if n == false
      res = res | (n << bits_so_far)
      bits_so_far += num_bits
    end
    res
  end
end

raise "Usage: ruby binindex.rb path/to/links.txt path/to/xindex.db path/to/put/index.bin" unless ARGV.length == 3
links_path, db_path, bin_path = ARGV

f = File.open(links_path)
p = Parser.new(f,db_path, bin_path)
p.document
