#![feature(env)]
#![feature(old_io)]
#![feature(old_path)]
#![feature(collections)]

#![allow(dead_code)]

use std::env;
use std::mem;
use std::old_io::File;

static FILE_HEADER_SIZE : usize = 4*4;
static PAGE_HEADER_SIZE : usize = 4;

static PAGE_USER_DATA : usize = 0;
static PAGE_LINKS : usize = 1;
static PAGE_BID_LINKS : usize = 2;

struct Graph<'a> {
    data : &'a mut [u32],
}

struct PageIter<'a> {
    g : &'a Graph<'a>,
    cur : usize,
}

impl<'a> Iterator for PageIter<'a> {
    type Item = usize;
    fn next(&mut self) -> Option<usize> {
        let next_page = self.cur + (PAGE_HEADER_SIZE+self.g.link_count(self.cur))*4;
        self.cur = next_page;
        if next_page >= self.g.data.len() * 4 { None } else { Some(next_page) }
    }
}

impl<'a> Graph<'a> {
    fn first_page(&self) -> usize {
        FILE_HEADER_SIZE
    }

    fn find_next(&self, page : usize) -> Option<usize> {
        let next_page = page + (PAGE_HEADER_SIZE+self.link_count(page))*4;
        if next_page >= self.data.len() * 4 { None } else { Some(next_page) }
    }

    fn find_next_unmarked(&self,start : usize) -> Option<usize> {
        let mut page = start;
        while self.user_data(page) != 0 {
            page = page + (PAGE_HEADER_SIZE+self.link_count(page))*4;
            if page >= self.data.len() * 4 { return None;}
        }
        Some(page)
    }

    fn pages(&self) -> PageIter {
        PageIter {g: self, cur: self.first_page()}
    }

    fn page_count(&self) -> u32 {
        self.data[1]
    }

    fn link_count(&self, page : usize) -> usize {
        self.data[page/4+PAGE_LINKS] as usize
    }

    fn bid_link_count(&self, page : usize) -> usize {
        self.data[page/4+PAGE_BID_LINKS] as usize
    }

    fn links(&'a self, page : usize) -> Vec<usize> {
        let start = page/4+PAGE_HEADER_SIZE;
        let end = start+self.link_count(page);
        let link_range = &self.data[start..end];
        link_range.iter().map(|x| *x as usize).collect::<Vec<usize>>()
    }

    fn set_user_data(&mut self, page : usize, data : u32) {
        self.data[page/4+PAGE_USER_DATA] = data;
    }

    fn user_data(&self, page : usize) -> u32 {
        self.data[page/4+PAGE_USER_DATA]
    }
}

fn flood_fill(graph : &mut Graph, start_page : usize, mark : u32) -> u32 {
    assert!(mark != 0);
    let mut stack = vec![start_page];
    let mut marked_count = 0;
    while !stack.is_empty() {
        let page = stack.pop().unwrap();

        if graph.user_data(page) != 0 {continue;}
        graph.set_user_data(page,mark); // mark visited
        // println!("Visiting {} with {} links",page,graph.link_count(page));
        marked_count += 1;

        for linked in graph.links(page) {
            // println!("Pushing link to {}", linked);
            stack.push(linked);
        }
    }
    marked_count
}

fn find_conn_components(graph : &mut Graph) {
    let mut start_page = graph.first_page();
    let mut comp_count = 0;
    loop {
        let count = flood_fill(graph, start_page,1);
        if count > 100 {
            println!("Found a connected component of {} nodes out of {} pages = {}.",
                     count,graph.page_count(),(count as f32 / graph.page_count() as f32));
        }
        comp_count += 1;

        let next_page = graph.find_next_unmarked(start_page);
        match next_page {
            Some(page) => start_page = page,
            None => break,
        }
    }
    println!("Found {} components.",comp_count);
}

fn fill_incoming_links(graph : &mut Graph) {
    let mut page = graph.first_page();
    // Increment link count on all linked to pages, then move to next
    loop {
        for linked in graph.links(page) {
            let incd = graph.user_data(linked)+1;
            graph.set_user_data(linked, incd);
        }

        match graph.find_next(page) {
            None => break,
            Some(new_page) => page = new_page,
        }
    }
}

static DATA_HIST_MAX : usize = 50;
fn analyze_user_data(graph : &Graph) {
    let mut hist : Vec<u32> = vec![0; DATA_HIST_MAX];
    for page in graph.pages() {
        let count = graph.user_data(page);
        if (count as usize) < DATA_HIST_MAX {
            hist[count as usize] += 1;
        }
    }
    println!("Incoming links:");
    for c in 0..hist.len() {
        println!("{}: {}",c, hist[c]);
    }
}

fn main() {
    let args: Vec<String> = env::args().map(|x| x.to_string()).collect();

    if args.len() != 2 {
        println!("Usage: ./strong_conn path/to/indexbi.bin");
        env::set_exit_status(1);
        return;
    }

    let bin_path = Path::new(&args[1]);
    println!("Analyzing {}...",bin_path.display());

    let mut file = File::open(&bin_path).ok().expect("Could not open graph file.");

    let mut graph_data : Vec<u32>;
    {
        let mut buf : Vec<u8> = file.read_to_end().ok().expect("Could not read file.");
        let len = buf.len();
        println!("Read {} bytes of file!", len);
        if len % 4 != 0 {
            println!("Invalid file size!");
            return;
        }
        let data_ptr : *mut u32 = unsafe {mem::transmute(buf.as_mut_ptr())};
        graph_data = unsafe { Vec::from_raw_buf(data_ptr, len / 4)};
    }
    let mut graph = Graph { data: graph_data.as_mut_slice() };
    println!("Read {} words of file!", graph.data.len());
    println!("Total pages: {}", graph.page_count());

    find_conn_components(&mut graph);

    // println!("Finding incoming links...");
    // fill_incoming_links(&mut graph);
    // println!("Analyzing incoming links...");
    // analyze_user_data(&graph);
}
