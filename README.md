# NuWav Ruby Gem (nu_wav)

[![Build Status](https://travis-ci.org/kookster/nu_wav.png?branch=master)](https://travis-ci.org/kookster/nu_wav)

NuWav is a pure Ruby audio WAVE file parser and writer.

It currently has support for basic WAVE files, Broadcast Wave Format (bext and mext chunks), and the cart chunk.
It will parse other chunks, but doesn't necessarily provide specific parsing for them.

It will look for a class based on the chunk name, so if you want to add 'fact' chunk parsing, you need to define a class like this (n.b. 'fact' chunks are already supported, this is an example from the code):

```ruby
module NuWav
  class FactChunk < NuWav::Chunk
    attr_accessor :samples_number

    def parse
      @samples_number = read_dword(0)
    end

    def to_s
      "<chunk type:fact samples_number:#{@samples_number} />"
    end
    
    def to_binary
      "fact" + write_dword(4) + write_dword(@samples_number)
    end
    
  end
end
```

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Andrew Kuklewicz kookster. See LICENSE for details.
