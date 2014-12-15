require "progress"

class Parser
  FILE_HEADER_SIZE = 4*4
  LINK_SIZE = 4
  HEADER_SIZE = 4*3

  def initialize(f)
    @f = f
    @out = File.open("newindex.bin","w")
  end

  def run
    header = @f.read(FILE_HEADER_SIZE)
    num_pages = header.unpack("LLLL")[1]
    @out.write(header)
    num_pages.times.with_progress do
      do_page
    end
  end

  def do_page
    # puts "Doing page at #{@f.pos}"
    this_page = @f.pos
    links = page_links
    double,single = links.partition { |l| bidirectional?(l,this_page)}
    output_page(double,single)
  end

  def output_page(double,single)
    total = double.length + single.length
    @out.write([0,total,double.length].pack("LLL")) # header
    @out.write(double.pack("L*"))
    @out.write(single.pack("L*"))
  end

  def page_links
    raise "Header fail at #{@f.pos - 4}" unless get_int == 0
    num_links = get_int
    raise "Already processed" unless get_int == 0
    (1..num_links).map {get_int}
  end

  private

  def get_int
    @f.read(4).unpack("L").first
  end

  def bidirectional?(page,other)
    old_pos = @f.pos
    @f.seek(page)
    links = page_links
    res = links.include?(other)
    @f.seek(old_pos)
    res
  end
end

f = File.open("index.bin")
p = Parser.new(f)
p.run
