module NuWav

  class WaveFile
    
    attr_accessor :header, :chunks

    def self.parse(wave_file)
      NuWav::WaveFile.new.parse(wave_file)
    end

    def initialize
      self.chunks = {}
    end
    
    def parse(wave_file)
      NuWav::WaveFile.log "Processing wave file #{wave_file.inspect}...."
      wave_file_size = File.size(wave_file)

      File.open(wave_file, File::RDWR) do |f|

        #only for windows, make sure we are operating in binary mode 
        f.binmode
        #start at the very beginning, a very good place to start
        f.seek(0)

        riff, riff_length = read_chunk_header(f)
        NuWav::WaveFile.log "riff: #{riff}"
        NuWav::WaveFile.log "riff_length: #{riff_length}"
        NuWav::WaveFile.log "wave_file_size: #{wave_file_size}"

        raise NotRIFFFormat unless riff == 'RIFF'
        riff_end = [f.tell + riff_length, wave_file_size].min

        riff_type = f.read(4)
        raise NotWAVEFormat unless riff_type == 'WAVE'

        @header = RiffChunk.new(riff, riff_length, riff_type)

        while (f.tell + 8) <= riff_end
          NuWav::WaveFile.log "while #{f.tell} < #{riff_end}"
          chunk_name, chunk_length = read_chunk_header(f)
          fpos = f.tell

          NuWav::WaveFile.log "found chunk: '#{chunk_name}', size #{chunk_length}"
          
          if chunk_name && chunk_length

            self.chunks[chunk_name.to_sym] = chunk_class(chunk_name).parse(chunk_name, chunk_length, f)
            parsed_chunk_size = self.chunks[chunk_name.to_sym].size

            NuWav::WaveFile.log "about to do a seek..."
            NuWav::WaveFile.log "f.seek #{fpos} + #{parsed_chunk_size}"
            f.seek(fpos + parsed_chunk_size)
            NuWav::WaveFile.log "seek done"

            if parsed_chunk_size.odd?
              NuWav::WaveFile.log("parsed_chunk_size is ODD #{chunk_name}: #{parsed_chunk_size}")
              pad = f.read(1)
              if (pad.nil? || pad.ord != 0)
                NuWav::WaveFile.log("NOT PADDED")
                f.seek(fpos + parsed_chunk_size)
              end
            end

          else
            NuWav::WaveFile.log "chunk or length was off - remainder of file does not parse properly: #{riff_end} - #{fpos} = #{riff_end - fpos}"
            f.seek(riff_end)
          end
        end
      end
      @chunks.each{|k,v| NuWav::WaveFile.log "#{k}: #{v}\n\n" unless k.to_s == 'data'}
      NuWav::WaveFile.log "parse done"
      self
    end

    def duration
      fmt = @chunks[:fmt]
      
      if (PCM_COMPRESSION.include?(fmt.compression_code.to_i))
        data = @chunks[:data]
        data.size / (fmt.sample_rate * fmt.number_of_channels * (fmt.sample_bits / 8))
      elsif (fmt.compression_code.to_i == MPEG_COMPRESSION)
        # <chunk type:fact samples_number:78695424 />
        fact = @chunks[:fact]
        fact.samples_number / fmt.sample_rate
      else
        raise "Duration implemented for PCM and MEPG files only."
      end
    end
    
    def is_mpeg?
      (@chunks[:fmt] && (@chunks[:fmt].compression_code.to_i == MPEG_COMPRESSION))
    end

    def is_pcm?
      (@chunks[:fmt] && (PCM_COMPRESSION.include?(@chunks[:fmt].compression_code.to_i)))
    end

    def to_s
      out = "NuWav:#{@header}\n"
      out = [:fmt, :fact, :mext, :bext, :cart, :data ].inject(out) do |s, chunk| 
        s += "#{self.chunks[chunk]}\n" if self.chunks[chunk]
        s
      end
    end

    def to_file(file_name, options={})
      if options[:add_extension] && !(file_name =~ /\.wav/)
        file_name += ".wav"
      end
      NuWav::WaveFile.log "NuWav::WaveFile.to_file: file_name = #{file_name}"
      
      #get all the chunks together to get final length
      chunks_out = [:fmt, :fact, :mext, :bext, :cart, :data].inject([]) do |list, chunk|
        if self.chunks[chunk]
          out = self.chunks[chunk].to_binary(options)
          NuWav::WaveFile.log out.length
          list << out
        end
        list
      end
      
      # TODO: handle other chunks not in the above list, but that might have been in a parsed wav
      
      riff_length = chunks_out.inject(0){|sum, chunk| sum += chunk.size}
      NuWav::WaveFile.log "NuWav::WaveFile.to_file: riff_length = #{riff_length}"
      
      #open file for writing
      open(file_name, "wb") do |o|
        #write the header
        o << "RIFF"
        o << [(riff_length + 4)].pack('V')
        o <<  "WAVE"
        #write the chunks
        chunks_out.each{|c| o << c}
      end      

    end
    
    def write_data_file(file_name)
      open(file_name, "wb") do |o|
        o << chunks[:data].data
      end      
    end

    
    # method to create a wave file using the 
    def self.from_mpeg(file_name)
      # read and display infos & tags
      NuWav::WaveFile.log "NuWav::from_mpeg::file_name:#{file_name}"
      mp3info = Mp3Info.open(file_name)
      NuWav::WaveFile.log mp3info
      file = File.open(file_name)
      wave = WaveFile.new
      
      # data chunk
      data = DataChunk.new_from_file(file)
      wave.chunks[:data] = data

      # fmt chunk
      fmt = FmtChunk.new
      fmt.compression_code = MPEG_COMPRESSION
      fmt.number_of_channels = (mp3info.channel_mode == "Single Channel") ? 1 : 2
      fmt.sample_rate = mp3info.samplerate
      fmt.byte_rate = mp3info.bitrate / 8 * 1000
      fmt.block_align = calculate_mpeg_frame_size(mp3info)
      fmt.sample_bits = 65535
      fmt.extra_size = 22
      fmt.head_layer = ACM_LAYERS[mp3info.layer.to_i-1]
      fmt.head_bit_rate = mp3info.bitrate * 1000
      fmt.head_mode = CHANNEL_MODES[mp3info.channel_mode]
      # fmt.head_mode_ext = (mp3info.channel_mode == "JStereo") ? 2**mp3info.mode_extension : 0
      fmt.head_mode_ext = (mp3info.channel_mode == "JStereo") ? 2**mp3info.header[:mode_extension] : 0
      # fmt.head_emphasis = mp3info.emphasis + 1
      fmt.head_emphasis = mp3info.header[:emphasis] + 1
      fmt.head_flags = calculate_mpeg_head_flags(mp3info)
      fmt.pts_low = 0
      fmt.pts_high = 0
      wave.chunks[:fmt] = fmt
      # NuWav::WaveFile.log "fmt: #{fmt}"
      
      # fact chunk
      fact = FactChunk.new
      fact.samples_number = calculate_mpeg_samples_number(file, mp3info)
      wave.chunks[:fact] = fact
      # NuWav::WaveFile.log "fact: #{fact}"
      
      #mext chunk
      mext = MextChunk.new
      mext.sound_information =  5
      mext.sound_information +=  2 if mp3info.header[:padding]
      mext.frame_size = calculate_mpeg_frame_size(mp3info)
      mext.ancillary_data_length = 0
      mext.ancillary_data_def = 0
      wave.chunks[:mext] = mext
      # NuWav::WaveFile.log "mext: #{mext}"
      
      
      #bext chunk
      bext = BextChunk.new
      bext.time_reference_high = 0
      bext.time_reference_low = 0
      bext.version = 1
      bext.coding_history = "A=MPEG1L#{mp3info.layer},F=#{mp3info.samplerate},B=#{mp3info.bitrate},M=#{CODING_HISTORY_MODE[mp3info.channel_mode]},T=PRX\r\n\0\0"
      wave.chunks[:bext] = bext
      # NuWav::WaveFile.log "bext: #{bext}"
      
      #cart chunk
      cart = CartChunk.new
      now = Time.now
      today = Date.today
      later = today << 12
      cart.version = '0101'
      cart.title = File.basename(file_name) # this is just a default
      cart.start_date = today.strftime("%Y-%m-%d")
      cart.start_time = now.strftime("%H:%M:%S")
      cart.end_date = later.strftime("%Y-%m-%d")
      cart.end_time = now.strftime("%H:%M:%S")
      cart.producer_app_id = 'NuWav'
      cart.producer_app_version = '1.0'
      cart.level_reference = 0
      cart.tag_text = "\r\n"
      wave.chunks[:cart] = cart
      # NuWav::WaveFile.log "cart: #{cart}"
      wave
    end
    
    def self.calculate_mpeg_samples_number(file, info)
      (File.size(file.path) / calculate_mpeg_frame_size(info)) * Mp3Info::SAMPLES_PER_FRAME[info.layer][info.mpeg_version]
    end
    
    def self.calculate_mpeg_head_flags(info)
      flags = 0
      flags += 1 if (info.header[:private_bit])
      flags += 2 if (info.header[:copyright])
      flags += 4 if (info.header[:original])
      flags += 8 if (info.header[:error_protection])
      flags += 16 if (info.mpeg_version > 0)
      flags
    end
    
    def self.calculate_mpeg_frame_size(info)
      samples_per_frame = Mp3Info::SAMPLES_PER_FRAME[info.layer][info.mpeg_version]
      ((samples_per_frame / 8) * (info.bitrate * 1000))/info.samplerate
    end

    protected
    
    def read_chunk_header(file)
      hdr = file.read(8)
      chunkName, chunkLen = hdr.unpack("A4V") rescue [nil, nil]
      # NuWav::WaveFile.log "chunkName: '#{chunkName}', chunkLen: '#{chunkLen}'"
      [chunkName, chunkLen]
    end

    def chunk_class(name)
      begin
        constantize("NuWav::#{camelize("#{name}_chunk")}")
      rescue NameError
        NuWav::Chunk
      end
        
    end
    
    # File vendor/rails/activesupport/lib/active_support/inflector.rb, line 147
    def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
      else
        lower_case_and_underscored_word.first + camelize(lower_case_and_underscored_word)[1..-1]
      end
    end

    # File vendor/rails/activesupport/lib/active_support/inflector.rb, line 252
    def constantize(camel_cased_word)
      unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
        raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
      end
      Object.module_eval("::#{$1}", __FILE__, __LINE__)
    end
    
    def self.log(m)
      if NuWav::DEBUG
        puts "#{Time.now}: NuWav: #{m}"
      end
    end

  end

end
