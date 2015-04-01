require 'ox'

class Handler < ::Ox::Sax
  LINK_REGEX = /\[\[([^|\]]+)(?:\|[^\]]+)?\]\]|(&lt;!--)|(--&gt;)/
  def initialize(link_file, redir_file)
    @link_file = File.open(link_file,"w")
    @redir_file = File.open(redir_file,"w")
  end

  def start_element(name)
    case name
    when :page
      @title = nil
      @links = []
      @is_redirect = false
    when :redirect
      @is_redirect = true
    when :title
      @in_title = true
    when :text
      @in_text = true
    end
  end
  def end_element(name)
    case name
    when :text
      do_page
      @in_text = false
    when :title
      @in_title = false
    end
  end
  def attr(name, value)
    if @is_redirect && name == :title
      @redirect = value
    end
  end
  def text(value)
    case
    when @in_title
      @title = value
    when @in_text
      @real_text = true
      value.scan(LINK_REGEX) do |lin, op, clos|
        # p [lin,op,clos,@real_text]
        if lin && @real_text
          @links << lin
        elsif op
          @real_text = false
        elsif clos
          @real_text = true
        end
      end
    end
  end

  private

  def do_page
    return unless @title
    if @is_redirect
      do_redirect
    else
      do_real_page
    end
  end

  def do_real_page
    @link_file.puts "#{@title}|#{@links.map{ |x| x.strip }.join('|')}"
  end

  def do_redirect
    return unless @redirect
    @redir_file.puts "#{@title}|#{@redirect}"
  end
end

raise "Usage: cat wikidump.xml | ruby 1-dumplinks.rb path/to/put/links.txt path/to/put/redirects.txt" unless ARGV.length == 2
puts "Dumping links..."
handler = Handler.new(ARGV[0],ARGV[1])
Ox.sax_parse(handler, STDIN)
