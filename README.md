wikicrush
=========

**WARNING:** The code doesn't really work right now as I'm in the middle of a major refactor after discovering a significant bug.

Extracts link graphs in a variety of formats from Wikipedia data dumps.
This includes a highly compact binary graph format designed for very efficient graph searches.

It can compress a recent 10GB compressed Wikipedia dump into a 500MB binary link graph and a 500MB sqlite database for translating article names into binary graph offsets.

Wikicrush was created for use in [Rate With Science](http://github.com/trishume/ratewithscience) where it allows sub-second breadth-first searches through all of Wikipedia on a cheap VPS with 1GB of RAM.


# The Files

## Features
- Relatively small binary graph data fits in memory allowing fast processing.
- Format design allows tight loops without external table lookups.
- Properly skips commented out links that don't show up on rendered Wikipedia pages.
- All links are validated to only include ones that go to valid pages.
- Link edges go through redirects transparently.
- Link lists sorted with bidirectional edges first.
- Provides space to store node data during graph algorithm processing.

## Primary Data

### indexbi.bin

This is the most important and awesome file, the crown jewel of the wikicrush project. It is a dense binary link graph that does not contain the titles of the articles and links to offsets within itself. This way one can run graph algorithms in tight loops without having to deal with strings and lookup tables. The graph transparently follows redirects in that if a page links to a redirect, it will be included in the file as a link to the page that the redirect goes to. Also note some pages link to themselves.

The file is a big array of 32-bit (4 byte) little-endian integers. This should be convenient to load into a big int array in the language of your choice.

The first 4 ints are the file header. First the version, next the total number of pages **P**, then 2 unused.
After this is **P** page data sections, each page is placed one after another until the end of the file.

##### Pages
Each page starts with a 3 int page header:

1. The first int is zero and is reserved for the user. I have used this for marking pages as seen and referencing the parent page during breadth-first-search path finding. This way no external data tables are necessary. Useful when you `read` the file into a mutable array in memory.
2. The number of links **N** that the page has.
3. The number of bidirectional links **B** the page has. These are links where the page being linked to also links back to this page. This generally implies a stronger connection between the topics of the two pages.

This header is followed by **N** ints containing the byte offsets of the pages linked to. The first **B** of these are the pages that also link back to this page. Note that the offsets are in *bytes* rather than ints so you may have to do some dividing by 4 when following these links to other pages in your data int array.

The next page section starts after the **N** links. This allows one to iterate through all the pages by skipping **N** ints forwards.


##### Overall Structure

In a wacky notation where `{}` denote logical sections that are really just adjacent in the file and each element is a 4-byte int the file looks like this:
```{{version, P, ?, ?}, {{0,N,B},{link, ...}},{{0,N,B},{link, ...}}, ...}```
See `analyze/graph.rb` for an example of how to use this file in Ruby or `analyze/strong_conn.rs` for a Rust example.

### xindex.db

This is an Sqlite database with a single table containing 3 columns and a row for every article:
```sql
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int,
  linkcount int
);
CREATE INDEX pages_offset ON pages (offset);
```
`title` is the lowercase article name, `offset` is the byte offset in the `indexbi.bin` file and `linkcount` is the number of links the article has.

It is how one maps from article titles to offsets in the `indexbi.bin` and `index.bin` files and back again.
It has indexes for both ways so is reasonably fast. It is used like this, at least in Ruby:
```ruby
def title_to_offset(s)
  rs = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1",s)
  return nil if rs.empty?
  rs.first.first
end
```

## Intermediate Files
These may be useful data but they are less polished than the primary files. They are used in the generation of the primary files. They are generally in easier formats (text) but contain gotchas that make them harder to work with like links to invalid pages.

### links.txt

This is the most basic of the files. It is a text file with a line for every article with the article name followed by a `|` followed by all the links it has separated by `|` characters. All article titles and link names are lower cased. Note that this link list also includes invalid links and links that go to redirects rather than articles. It is the simplest format but in some ways the hardest to handle robustly. It looks like this:

```
albedo|latin|diffuse reflection|dimensionless number|frequency|visible light
alabama|flag of alabama|seal of alabama|red hills salamander|northern flicker
```

Except the lines are way way longer since articles often have hundreds of links.

### redirects.txt

Text file containing one line for every redirect on Wikipedia. With the redirect followed by the page it redirects to separated by a `|`. Both source and target are lowercased, this leads to many like `africa|africa` which previously redirected to different capitalizations but no longer make sense. Redirects are not guaranteed to point to valid pages.

### titles.txt

Contains all valid pages and redirects that point to valid pages. Lowercased one per line.

### links-raw.txt and redirects-raw.txt

These are the files produced directly from the wiki dump. They are **not** lowercased and not filtered.
They still contain `File:`, `Wikipedia:`, etc... pages.

### links-filt.txt

Same as `links-raw.txt` but filtered through grep to weed out pages matching `^(File|Template|Wikipedia|Help|Draft):`.

### index.bin

Same as `indexbi.bin` but without bidirectional links sorted first and with the **B** field set to `0`.
The only point of using this file is if you don't want to bother generating `indexbi.bin`.

## Generating the Files

1. Git clone the latest wikicrush
1. Run `bundle install` in the wikicrush directory.
1. Download the latest `enwiki-<some_date>-pages-articles.xml.bz2`
1. Symlink (or move) the dump into the `data` directory of your wikicrush clone as `data/pages-articles.xml.bz2`
1. Run `rake data/indexbi.bin` in the wikicrush directory.
1. Wait somewhere between 12-48 hours depending on how fast your computer is. At times this will take up to 3GB of RAM and 8GB of hard drive space.
1. Tada you have the data files!

One of these processes will talk about "Fail"s, don't worry about this, it is expected. There is a bug that affects %0.1 of Wikipedia articles where the link count at different stages differs by one. These pages simply have an extra link to themself added to compensate.

If you want to do this in a more nuanced way there's more fine grained control. You can ask Rake to generate the files one at a time and delete the intermediate steps when you no longer need them to save disk space if you want.
Refer to the Rakefile for which files depend on which others. If one of the steps crashes on you due to lack of disk space or memory, delete the half-finished file it was working on, resolve the issue and re-run the rake command.

You may also want to modify some of the steps if you want. Particularly the article filtering step in case you want to for example exclude "List of X" articles.

This also works for other wikis such as the Simple English Wikipedia, I use the simple english wiki dump for testing because it is much smaller so all the steps run in minutes rather than hours, but it is still in a language I understand.

## Tips for Use

- Read the `indexbi.bin` file into a big int32 array.
- Make good use of the user data storage in your algorithms. If you want to use an external table simply fill the user data segments with incrementing indices into that table.
- Try to only use the Sqlite file at the edges of your algorithm when communicating with the user. I translate the user input to offsets before I start and then the graph algorithm output back to titles after I'm done. Thus avoiding touching strings during processing.
- Check out the code I've wrote that uses and generates these files. There's Ruby and Rust in this repo and Nim and more Rust in my `ratewithscience` repo.
