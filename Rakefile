RAW_DUMP_PATH = "data/pages-articles.xml.bz2"

file "data/links-raw.txt", :dump_path do |t,args|
  args.with_defaults(:dump_path => RAW_DUMP_PATH)
  dump = args[:dump_path]
  raise "#{dump} must exist" unless File.exist?(dump)
  sh "bzip2 -dc \"#{dump}\" | ruby gen/dumplinks.rb data/links-raw.txt data/redirects-raw.txt"
end

file "data/links-filt.txt" => ["data/links-raw.txt"] do
  sh "grep -Ev \"^(File|Template|Help|Draft):\" data/links-raw.txt > data/links-filt.txt"
end

file "data/titles.txt" => ["data/links-filt.txt"] do
  sh "cut -d'|' -f1 data/links-filt.txt > data/titles.txt"
end

file "data/redirects.txt" => ["data/links-raw.txt","data/titles.txt"] do
  ruby "gen/filtredirs.rb data/titles.txt data/redirects-raw.txt data/redirects.txt"
end

file "data/links.txt" => ["data/links-filt.txt","data/redirects.txt","data/titles.txt"] do
  ruby "gen/proclinks.rb data/titles.txt data/redirects.txt data/links-filt.txt data/links.txt"
end

file "data/xindex.db" => ["data/links.txt"] do
  ruby "gen/sqlindex.rb data/links.txt data/xindex.db"
end

file "data/index.bin" => ["data/links.txt","data/xindex.db"] do
  ruby "gen/binindex.rb data/links.txt data/xindex.db data/index.bin"
end

file "data/indexbi.bin" => ["data/index.bin"] do
  if system("which","nim")
    sh "nim c -d:release gen/doublelink.nim"
    sh "./gen/doublelink"
  else
    ruby "gen/doublelink.rb data/index.bin data/indexbi.bin"
  end
end

directory "bin"
file "bin/strong_conn" => ["bin"] do
  sh "rustc -O -o bin/strong_conn analyze/strong_conn.rs"
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

task :invalid_links do
  sh "ruby analyze/invalid_links.rb data/links.txt data/titles.txt 1000 > data/invalid-links.txt"
end

task :strong_conn => ["bin/strong_conn"] do
  sh "./bin/strong_conn data/index.bin"
end

task :nocase => ["data/xindex.db"] do
  cp "data/xindex.db", "data/xindex-nocase.db"
  sh "sqlite3 data/xindex-nocase.db < gen/nocase.sql"
end
