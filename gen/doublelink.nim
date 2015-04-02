import sequtils, queues, strutils, algorithm

type
  Graph* = seq[int32]
  Page = int32

const
  kPageUserDataField = 0
  kPageLinksField = 1
  kPageBidLinksField = 2
  kPageHeaderSize = 3
  kFirstPageIndex = 4

proc offset*[A](some: ptr A; b: int): ptr A =
  result = cast[ptr A](cast[int](some) + (b * sizeof(A)))
iterator iterPtr*[A](some: ptr A; num: int): A =
  for i in 0.. <num:
    yield some.offset(i)[]
proc load_bin_graph*() : Graph =
  echo "loading graph..."
  var f : File
  discard open(f,"data/index.bin")
  defer: close(f)
  let size : int = getFileSize(f).int
  let count = size /% 4
  var s : seq[int32]
  newSeq(s, count)
  shallow(s)
  discard readBuffer(f,addr(s[0]),size)
  return s

proc write_bin_graph(g : var Graph) =
  echo "Writing graph..."
  var f : File
  discard open(f,"data/indexbi.bin",fmWrite)
  defer: close(f)
  discard f.writeBuffer(addr(g[0]),g.len()*4)
  echo "Wrote file..."

iterator link_indices(g : Graph, p : Page) : Page =
  block:
    let ind = p /% 4
    let link_count = g[ind + kPageLinksField]
    let start = ind+kPageHeaderSize
    # echo "Yielding ", link_count, " links for ", p
    for i in start.. <(start+link_count):
      yield i
iterator all_pages(g : Graph) : Page =
  block:
    var i = kFirstPageIndex
    while i < g.len:
      yield (i*4).Page
      i += kPageHeaderSize+g[i+kPageLinksField]

proc links_to(g : Graph, p1 : Page, p2 : Page) : bool =
  for link in link_indices(g,p1):
    # echo "Checking ", link
    if g[link] == p2:
      return true
  return false

proc double_link(g : var Graph) =
  echo "Processing..."
  for p in all_pages(g):
    var store = (p /% 4) + kPageHeaderSize
    var numbid = 0
    for i in link_indices(g, p):
      if links_to(g,g[i],p):
        swap(g[store],g[i])
        store += 1
        numbid += 1
    g[p /% 4 + kPageBidLinksField] = numbid.int32

when isMainModule:
  var data = load_bin_graph()
  data.double_link()
  write_bin_graph(data)
