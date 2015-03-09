RAW_DUMP_PATH = "data/pages-articles.xml.bz2"

file "data/links-raw.txt", :dump_path do |t,args|
  args.with_defaults(:dump_path => RAW_DUMP_PATH)
  dump = args[:dump_path]
  die "#{dump} must exist" unless File.exist?(dump)
  sh "bzip2 -dc \"#{dump}\" | ruby gen/1-dumplinks.rb data/links-raw.txt data/redirects.txt"
end

file "data/links.txt" => ["data/links-raw.txt"] do
  sh "grep -Ev \"^(File|Template|Wikipedia|Help|Draft)\" data/links-raw.txt > data/links.txt"
end

file "data/titles.txt" => ["data/links.txt"] do
  ruby "gen/2-titles.rb data/links.txt data/redirects.txt data/titles.txt"
end

file "data/xindex.db" => ["data/links.txt","data/titles.txt"] do
  ruby "gen/3-sqlindex.rb data/links.txt data/titles.txt data/xindex.db"
end

file "data/index.bin" => ["data/links.txt","data/xindex.db"] do
  ruby "gen/4-binindex.rb data/links.txt data/redirects.txt data/xindex.db data/index.bin"
end

file "data/indexbi.bin" => ["data/index.bin"] do
  ruby "gen/5-doublelink.rb data/index.bin data/indexbi.bin"
end

task :verify => "data/index.bin" do
  ruby "analyze/verify.rb data/index.bin data/xindex.db"
end

task :inspect, :page do |t, args|
  ruby "analyze/inspect.rb data/indexbi.bin data/xindex.db \"#{args[:page]}\""
end

task :link_stats do
  ruby "analyze/link_stats.rb data/links.txt data/titles.txt"
end
