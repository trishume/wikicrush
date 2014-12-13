class Parser
  def initialize(f)
    @f = f
  end

  def header
    @f.seek(38)
  end

  def document
    match("<d>")
    while @f.read(3) == "<p>"
      page(@f)
    end
  end

  def page
    match("<p><t>")
    puts @f.gets("<") # title
    match("/t>")
  end

  private

  def match(s)
    raise "invalid" unless @f.read(s.length) == s
  end
end

f = File.open("/Users/tristan/misc/simplewiki-links.xml")
p = Parser.new(f)
p.header
p.document
