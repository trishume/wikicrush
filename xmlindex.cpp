#include <iostream>
#include <fstream>
using namespace std;

void parseDocument(istream &in) {
  in.ignore(3); // <d>

  std::string tag;
  tag.resize(3, ' '); // reserve space
  char* tagptr = &*tag.begin();
  while(1) {
    in.read(tagptr,3);
  }
}

int main() {
  ifstream in("/Users/tristan/misc/simplewiki-links.xml");
  in.seekg(38);
  char c;
  in >> c;
  std::cout << "Char: " << c << std::endl;
  in.close();
}
