class Parser
  def initialize(f)
    @f = f
    @out = File.open("titles.txt","w")
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
    @out.puts name
    match("/t>")
    links
    match(">") # only thing left over after <l> tries to consume </p>
  end

  def links
    while @f.read(3) == "<l>"
      @f.gets("<")
      match("/l>")
    end
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
p.header
p.document
