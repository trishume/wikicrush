Wikicrush
=========

Extracts link graphs in a variety of formats from Wikipedia data dumps.
This includes a highly compact binary graph format designed for very efficient graph searches.

It can compress a recent 10GB compressed Wikipedia dump into a 630MB binary link graph and a 550MB sqlite database for translating article names into binary graph offsets.

Wikicrush was created for use in [Rate With Science](http://github.com/trishume/ratewithscience) where it allows sub-second breadth-first searches through all of Wikipedia on a cheap VPS with 1GB of RAM.

### Getting the Data

You can either run the process yourself and get all the files plus control over the source dump by following the steps at the bottom or you can use the download I have prepared.

The download is a zip file containing just `xindex.db` and `indexbi.bin` and was generated from `enwiki-20150205-pages-articles.xml.bz2` (i.e the February 2015 english Wikipedia dump). The file is 740MB and can be downloaded here: [http://thume.net/bigdownloads/wikidata.zip](http://thume.net/bigdownloads/wikidata.zip). **Note:** This uses the old graph format v1, see the `v1` branch readme for the old format. I'll try and process another more recent wiki dump into the new format soon.


# The Files

## Features
- Relatively small binary graph data fits in memory allowing fast processing.
- Format design allows tight loops without external table lookups.
- Properly skips commented out links that don't show up on rendered Wikipedia pages.
- All links are validated to only include ones that go to valid pages.
- Link edges go through redirects transparently.
- Link lists sorted with bidirectional edges first.
- Provides space to store node data during graph algorithm processing.
- Tested and verified to accurately capture the links over many weeks of bug fixing and use in Rate With Science.

## Primary Data

### indexbi.bin

This is the most important and awesome file, the crown jewel of the Wikicrush project. It is a dense binary link graph that does not contain the titles of the articles and links to offsets within itself. This way one can run graph algorithms in tight loops without having to deal with strings and lookup tables. The graph transparently follows redirects in that if a page links to a redirect, it will be included in the file as a link to the page that the redirect goes to. Also note some pages link to themselves.

The file is a big array of 32-bit (4 byte) little-endian integers. This should be convenient to load into a big int array in the language of your choice.

The first 4 ints are the file header. First the version, next the total number of pages **P**, then 2 unused.
After this is **P** page data sections, each page is placed one after another until the end of the file.

##### Pages
Each page starts with a 4 int page header:

1. The first int is zero and is reserved for the user. I have used this for marking pages as seen and referencing the parent page during breadth-first-search path finding. This way no external data tables are necessary. Useful when you `read` the file into a mutable array in memory.
2. The number of links **N** that the page has.
3. The number of bidirectional links **B** the page has. These are links where the page being linked to also links back to this page. This generally implies a stronger connection between the topics of the two pages.
4. A metadata integer **M** with a bunch of bit fields and some zeroes that should be ignored for adding future metadata

This header is followed by **N** ints containing the byte offsets of the pages linked to. The first **B** of these are the pages that also link back to this page. Note that the offsets are in *bytes* rather than ints so you may have to do some dividing by 4 when following these links to other pages in your data int array.

The next page section starts after the **N** links. This allows one to iterate through all the pages by skipping **N** ints forwards.


##### Overall Structure

In a wacky notation where `{}` denote logical sections that are really just adjacent in the file and each element is a 4-byte int the file looks like this:
```{{version, P, ?, ?}, {{0,N,B,M},{link, ...}},{{0,N,B,M},{link, ...}}, ...}```
See `analyze/graph.rb` for an example of how to use this file in Ruby or `analyze/strong_conn.rs` for a Rust example.

##### Metadata
32 bits of metadata packed into integer bit fields of **M**, from least significant bits to most significant:

    3 bits = log10(length of article markup in bytes)
    4 bits = min(number of words in title, 15)
    1 bit = 1 if is a disambiguation page
    3 bits = article namespace index in [normal, category, wikipedia, portal, book ... reserved for future ... 7=other namespace]
    1 bit = 1 if page is a "List of" article
    1 bit = 1 if page is a year
    The following bits are not set by this script but their places are reserved
    1 bit = if the article is a featured article
    1 bit = if the article is a "good" article
    (32-15=17) bits of zeroes reserved for future use

Example: if you want to extract the article namespace number from an integer `m` you could use code like (C-style bitwise operations):

```c
    (m >> 8) & 0b111 // or 0x7 or just 7
```

Because the namespace field is offset (3+4+1)=8 bits from the start and is 3 bits long.

### xindex.db

This is an Sqlite database with a single table containing 3 columns and a row for every article:
```sql
create table pages (
  title varchar(256) PRIMARY KEY,
  offset int
);
CREATE INDEX pages_offset ON pages (offset);
```
`title` is the article name, `offset` is the byte offset in the `indexbi.bin` file.

It is how one maps from article titles to offsets in the `indexbi.bin` and `index.bin` files and back again.
It has indexes for both ways so is reasonably fast. It is used like this, at least in Ruby:
```ruby
def title_to_offset(s)
  # Use COLLATE NOCASE if accepting human input and don't want case sensitivity
  rs = @db.execute("SELECT offset FROM pages WHERE title = ? LIMIT 1",s)
  return nil if rs.empty?
  rs.first.first
end
```

Note that this table does not contain redirects, that is something that might come in a future version.

### xindex-nocase.db

Generated by running `rake nocase` this is the same as `xindex.db` except with an extra index created like this:

    create index pages_nocase on pages (title collate nocase);

It is useful for interactive apps like [Rate With Science](http://github.com/trishume/ratewithscience) because it makes case insensitive `COLLATE NOCASE` queries much much faster.
The cost is additional file size.

### links.txt

This is a text file with a line for every article with the article name followed by a metadata column and then all the links it has separated by `|` characters. All links are with redirects already followed and all links are verified to point to a valid page and are unique-d (no link included more than once). This is the easiest file to work with for some cases but certainly not the most efficient.

The metadata column currently contains the length of the page markup in bytes followed by a `-` and then a series of characters each of which represents a page tag. Currently the only tag is `D` which signifies a disambiguation page.

Here's an example with many links truncated since these pages actually have hundreds of links:

```
A|2889-|Letter (alphabet)|Vowel|ISO basic Latin alphabet|Alpha|Italic type
Achilles|2924-|Kantharos|Vulci|Cabinet des Médailles|Phthia|Thetis|Chiton (costume)
```

Note that this is meant to be parsed with a `split` operation and as such a page with no links is just the page name with no `|`.


## Intermediate Files
These may be useful data but they are less polished than the primary files. They are used in the generation of the primary files. They are generally in easier formats (text) but contain gotchas that make them harder to work with like links to invalid pages.


Except the lines are way way longer since articles often have hundreds of links.

### redirects.txt

Text file containing one line for every redirect on Wikipedia. With the redirect followed by the page it redirects to separated by a `|`. Filtered to only include redirects where the target is a valid page and the source is not a valid page.

### titles.txt

Contains the titles of all valid pages one per line.

### links-raw.txt and redirects-raw.txt

These are the files produced directly from the wiki dump.
They still contain `File:`, `Wikipedia:`, etc... pages.

### links-filt.txt

Same as `links-raw.txt` but filtered through grep to weed out pages matching `^(File|Template|Wikipedia|Help|Draft):`.

### index.bin

Same as `indexbi.bin` but without bidirectional links sorted first and with the **B** field set to `0`.
The only point of using this file is if you don't want to bother generating `indexbi.bin`.

## Generating the Files

1. Install Ruby+Bundler and optionally [Nim](http://nim-lang.org/) to make one process WAY faster.
1. Git clone the latest Wikicrush
1. Run `bundle install` in the `wikicrush` directory.
1. Download the latest `enwiki-<some_date>-pages-articles.xml.bz2`
1. Symlink (or move) the dump into the `data` directory of your Wikicrush clone as `data/pages-articles.xml.bz2`
1. Run `rake data/indexbi.bin` in the `wikicrush` directory.
1. Wait somewhere between 12-48 hours depending on how fast your computer is. At times this will take up to 3GB of RAM and 15GB of hard drive space.
1. Tada you have the data files!

If you want to do this in a more nuanced way there's more fine grained control. You can ask Rake to generate the files one at a time and delete the intermediate steps when you no longer need them to save disk space if you want.
Refer to the Rakefile for which files depend on which others. If one of the steps crashes on you due to lack of disk space or memory, delete the half-finished file it was working on, resolve the issue and re-run the rake command.

You may also want to modify some of the steps if you want. Particularly the article filtering step in case you want to for example exclude "List of X" articles.

This also works for other wikis such as the Simple English Wikipedia, I use the simple english wiki dump for testing because it is much smaller so all the steps run in minutes rather than hours, but it is still in a language I understand.

## Tips for Use

- Read the `indexbi.bin` file into a big int32 array.
- Make good use of the user data storage in your algorithms. If you want to use an external table simply fill the user data segments with incrementing indices into that table.
- Try to only use the Sqlite file at the edges of your algorithm when communicating with the user. I translate the user input to offsets before I start and then the graph algorithm output back to titles after I'm done. Thus avoiding touching strings during processing.
- Check out the code I've wrote that uses and generates these files. There's Ruby and Rust in this repo and Nim and more Rust in my `ratewithscience` repo.
