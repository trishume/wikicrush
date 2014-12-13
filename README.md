wikicrush
=========

Processor scripts for graphipedia dumps to crush them into a dense binary format that is easy to pathfind with.

Very much a work in progress, doesn't do what it says yet.

## The problem

[graphipedia](https://github.com/mirkonasato/graphipedia) is a cool script that can produce xml files out of 
Wiki dumps that contain only the link information, but they are still too big because they contain lots of
redundant information. The current wikipedia dump (10GB) produces a 2GB file.

By assigning pages an id number and outputing things in a binary format it can be made so that a pathfinding
program can load the whole dump into memory.
