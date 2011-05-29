# http://www.prss.org/contentdepot/automation_specifications.cfm
# Bill Kelly <billk <at> cts.com> http://article.gmane.org/gmane.comp.lang.ruby.general/43110
# BWF intro  http://en.wikipedia.org/wiki/Broadcast_Wave_Format
# BWF basics http://tech.ebu.ch/docs/tech/tech3285.pdf
# BWF mpeg   http://tech.ebu.ch/docs/tech/tech3285s1.pdf

require 'rubygems'
require 'mp3info'
require 'date'
require 'tempfile'

module NuWav

  DEBUG = false

  # 1 is standard integer based, 3 is the floating point PCM
  PCM_INTEGER_COMPRESSION = 1
  PCM_FLOATING_COMPRESSION = 3
  PCM_COMPRESSION = [PCM_INTEGER_COMPRESSION, PCM_FLOATING_COMPRESSION]
  
  MPEG_COMPRESSION = 80
  
  ACM_MPEG_LAYER1 = 1
  ACM_MPEG_LAYER2 = 2
  ACM_MPEG_LAYER3 = 4 
  
  ACM_LAYERS = [ACM_MPEG_LAYER1, ACM_MPEG_LAYER2, ACM_MPEG_LAYER3]

  ACM_MPEG_STEREO       = 1
  ACM_MPEG_JOINTSTEREO  = 2
  ACM_MPEG_DUALCHANNEL  = 4
  ACM_MPEG_SINGLECHANNEL= 8
  
  CHANNEL_MODES = {'Stereo'=>ACM_MPEG_STEREO, 'JStereo'=>ACM_MPEG_JOINTSTEREO, 'Dual Channel'=>ACM_MPEG_DUALCHANNEL, 'Single Channel'=>ACM_MPEG_SINGLECHANNEL}
  
  CODING_HISTORY_MODE = {'Single Channel'=>'mono', 'Stereo'=>'stereo', 'Dual Channel'=>'dual-mono', 'JStereo'=>'joint-stereo'}

  class NotRIFFFormat < StandardError; end
  class NotWAVEFormat < StandardError; end
  
  class WaveFile
    
    attr_accessor :header, :chunks

    def self.parse(wave_file)
      wf = NuWav::WaveFile.new
      wf.parse(wave_file)
      wf
    end

    def initialize
      self.chunks = {}
    end
    
    def parse(wave_file)
      NuWav::WaveFile.log "Processing wave file #{wave_file.inspect}...."
      File.open(wave_file, File::RDWR) do |f|

        #only for windows, make sure we are operating in binary mode 
        f.binmode
        #start at the very beginning, a very good place to start
        f.seek(0)

        riff, riff_length = read_chunk_header(f)
        NuWav::WaveFile.log "riff: #{riff}"
        NuWav::WaveFile.log "riff_length: #{riff_length}"
        raise NotRIFFFormat unless riff == 'RIFF'
        riff_end = f.tell + riff_length

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

            NuWav::WaveFile.log "about to do a seek..."
            NuWav::WaveFile.log "f.seek #{fpos} + #{self.chunks[chunk_name.to_sym].size}"
            f.seek(fpos + self.chunks[chunk_name.to_sym].size)
            NuWav::WaveFile.log "seek done"
          else
            NuWav::WaveFile.log "chunk or length was off - remainder of file does not parse properly: #{riff_end} - #{fpos} = #{riff_end - fpos}"
            f.seek(riff_end)
          end
        end
      end
      @chunks.each{|k,v| NuWav::WaveFile.log "#{k}: #{v}\n\n" unless k.to_s == 'data'}
      NuWav::WaveFile.log "parse done"
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

    def to_file(file_name, add_extension=false)
      if add_extension && !(file_name =~ /\.wav/)
        file_name += ".wav"
      end
      NuWav::WaveFile.log "NuWav::WaveFile.to_file: file_name = #{file_name}"
      
      #get all the chunks together to get final length
      chunks_out = [:fmt, :fact, :mext, :bext, :cart, :data].inject([]) do |list, chunk|
        if self.chunks[chunk]
          out = self.chunks[chunk].to_binary
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
      cart.producer_app_id = 'PRX'
      cart.producer_app_version = '3.0'
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
      chunkName, chunkLen = hdr.unpack("A4V")
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
        NuWav::WaveFile.log "#{Time.now}: NuWav: #{m}"
      end
    end

  end
  
  class Chunk
    attr_accessor :id, :size, :raw
    
    def self.parse(id, size, file)
      raw = file.read(size)
      chunk = self.new(id, size, raw)
      chunk.parse
      return chunk
    end

    def initialize(id=nil, size=nil, raw=nil)
      @id, @size, @raw = id, size, raw
    end
    
    def parse
    end

    def read_dword(start)
      @raw[start..(start+3)].unpack('V').first
    end

    def read_word(start)
      @raw[start..(start+1)].unpack('v').first
    end
    
    def read_char(start, length=(@raw.length-start))
      @raw[start..(start+length-1)]
    end

    def write_dword(val)
      val ||= 0
      [val].pack('V')
    end

    def write_word(val)
      val ||= 0
      [val].pack('v')
    end
    
    def write_char(val, length=nil)
      val ||= ''
      length ||= val.length
      # NuWav::WaveFile.log "length:#{length} val.length:#{val.length} val:#{val}"
      padding = "\0" * [(length - val.length), 0].max
      out = val[0,length] + padding
      # NuWav::WaveFile.log out
      out
    end
    
    def to_binary
    end
  end


  class RiffChunk
    attr_accessor :id, :size, :riff_type
    
    def initialize(riff_name, riff_length, riff_type)
      @id, @size, @riff_type = riff_name, riff_length, riff_type
    end

    def to_s
      "<chunk type:riff id:#{@id} size:#{@size} type:#{@riff_type} />"
    end

  end

  class FmtChunk < Chunk
    
    attr_accessor :compression_code, :number_of_channels, :sample_rate, :byte_rate, :block_align, :sample_bits, :extra_size, :extra, 
      :head_layer, :head_bit_rate, :head_mode, :head_mode_ext, :head_emphasis, :head_flags, :pts_low, :pts_high
    
    def parse
      NuWav::WaveFile.log "@raw.size = #{@raw.size}"
      @compression_code =   read_word(0)
      @number_of_channels = read_word(2)
      @sample_rate =        read_dword(4)
      @byte_rate =          read_dword(8)
      @block_align =        read_word(12)
      @sample_bits =        read_word(14)
      @extra_size =         read_word(16)
      
      if (@compression_code.to_i == MPEG_COMPRESSION)
        @head_layer =       read_word(18)
        @head_bit_rate =    read_dword(20)
        @head_mode =        read_word(24)
        @head_mode_ext =    read_word(26)
        @head_emphasis =    read_word(28)
        @head_flags =       read_word(30)
        @pts_low =          read_dword(32)
        @pts_high =         read_dword(36)
      end
    end

    def to_binary
      out = ''
      out += write_word(@compression_code)
      out += write_word(@number_of_channels)
      out += write_dword(@sample_rate)
      out += write_dword(@byte_rate)
      out += write_word(@block_align)
      out += write_word(@sample_bits)
      out += write_word(@extra_size)
      
      if (@compression_code.to_i == MPEG_COMPRESSION)
        out += write_word(@head_layer)
        out += write_dword(@head_bit_rate)
        out += write_word(@head_mode)
        out += write_word(@head_mode_ext)
        out += write_word(@head_emphasis)
        out += write_word(@head_flags)
        out += write_dword(@pts_low)
        out += write_dword(@pts_high)
      end
      "fmt " + write_dword(out.size) + out
    end
    
    def to_s
      extra = if (@compression_code.to_i == MPEG_COMPRESSION)
        ", head_layer:#{head_layer}, head_bit_rate:#{head_bit_rate}, head_mode:#{head_mode}, head_mode_ext:#{head_mode_ext}, head_emphasis:#{head_emphasis}, head_flags:#{head_flags}, pts_low:#{pts_low}, pts_high:#{pts_high}"
      else
        ""
      end
      "<chunk type:fmt compression_code:#{compression_code}, number_of_channels:#{number_of_channels}, sample_rate:#{sample_rate}, byte_rate:#{byte_rate}, block_align:#{block_align}, sample_bits:#{sample_bits}, extra_size:#{extra_size} #{extra} />"
    end    
  end
  
  class FactChunk < Chunk
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
  
  class MextChunk < Chunk
    attr_accessor :sound_information, :frame_size, :ancillary_data_length, :ancillary_data_def, :reserved
    
    def parse
      @sound_information =      read_word(0)
      @frame_size =             read_word(2)
      @ancillary_data_length =  read_word(4)
      @ancillary_data_def =     read_word(6)
      @reserved =               read_char(8,4)
    end
    
    def to_s
      "<chunk type:mext sound_information:(#{sound_information}) #{(0..15).inject(''){|s,x| "#{s}#{sound_information[x]}"}}, frame_size:#{frame_size}, ancillary_data_length:#{ancillary_data_length}, ancillary_data_def:#{(0..15).inject(''){|s,x| "#{s}#{ancillary_data_def[x]}"}}, reserved:'#{reserved}' />"
    end
    
    def to_binary
      out = "mext" + write_dword(12)
      out += write_word(@sound_information)
      out += write_word(@frame_size)
      out += write_word(@ancillary_data_length)
      out += write_word(@ancillary_data_def)
      out += write_char(@reserved, 4)
      out
    end
  end

  class BextChunk < Chunk
    attr_accessor :description, :originator, :originator_reference, :origination_date, :origination_time, :time_reference_low, :time_reference_high, 
      :version, :umid, :reserved, :coding_history
      
    def parse
      @description =            read_char(0,256)
      @originator =             read_char(256,32)
      @originator_reference =   read_char(288,32)
      @origination_date =       read_char(320,10)
      @origination_time =       read_char(330,8)
      @time_reference_low =     read_dword(338)
      @time_reference_high =    read_dword(342)
      @version =                read_word(346)
      @umid =                   read_char(348,64)
      @reserved =               read_char(412,190)
      @coding_history =         read_char(602)
    end
    
    def to_s
      "<chunk type:bext description:'#{description}', originator:'#{originator}', originator_reference:'#{originator_reference}', origination_date:'#{origination_date}', origination_time:'#{origination_time}', time_reference_low:#{time_reference_low}, time_reference_high:#{time_reference_high}, version:#{version}, umid:#{umid}, reserved:'#{reserved}', coding_history:#{coding_history} />"
    end

    def to_binary
      out = "bext" + write_dword(602 + @coding_history.length )
      out += write_char(@description, 256)
      out += write_char(@originator, 32)
      out += write_char(@originator_reference, 32)
      out += write_char(@origination_date, 10)
      out += write_char(@origination_time, 8)
      out += write_dword(@time_reference_low)
      out += write_dword(@time_reference_high)
      out += write_word(@version)
      out += write_char(@umid, 64)
      out += write_char(@reserved, 190)
      out += write_char(@coding_history)
      # make sure coding history ends in '\r\n'
      out
    end
      
  end

  class CartChunk < Chunk
    attr_accessor :version, :title, :artist, :cut_id, :client_id, :category, :classification, :out_cue, :start_date, :start_time, :end_date, :end_time, 
      :producer_app_id, :producer_app_version, :user_def, :level_reference, :post_timer, :reserved, :url, :tag_text

    def parse
      @version =              read_char(0,4)
      @title =                read_char(4,64)
      @artist =               read_char(68,64)
      @cut_id =               read_char(132,64)
      @client_id =            read_char(196,64)
      @category =             read_char(260,64)
      @classification =       read_char(324,64)
      @outcue =               read_char(388,64)
      @start_date =           read_char(452,10)
      @start_time =           read_char(462,8)
      @end_date =             read_char(470,10)
      @end_time =             read_char(480,8)
      @producer_app_id =      read_char(488,64)
      @producer_app_version = read_char(552,64)
      @user_def =             read_char(616,64)
      @level_reference =      read_dword(680)
      @post_timer =           read_char(684,64)
      @reserved =             read_char(748,276)
      @url =                  read_char(1024,1024)
      @tag_text =             read_char(2048)
    end

    def to_s
      "<chunk type:cart version:#{version}, title:#{title}, artist:#{artist}, cut_id:#{cut_id}, client_id:#{client_id}, category:#{category}, classification:#{classification}, out_cue:#{out_cue}, start_date:#{start_date}, start_time:#{start_time}, end_date:#{end_date}, end_time:#{end_time}, producer_app_id:#{producer_app_id}, producer_app_version:#{producer_app_version}, user_def:#{user_def}, level_reference:#{level_reference}, post_timer:#{post_timer}, reserved:#{reserved}, url:#{url}, tag_text:#{tag_text} />"
    end
    
    def to_binary
      out = "cart" + write_dword(2048 + @tag_text.length )
      out += write_char(@version,4)
      out += write_char(@title,64)
      out += write_char(@artist,64)
      out += write_char(@cut_id,64)
      out += write_char(@client_id,64)
      out += write_char(@category,64)
      out += write_char(@classification,64)
      out += write_char(@outcue,64)
      out += write_char(@start_date,10)
      out += write_char(@start_time,8)
      out += write_char(@end_date,10)
      out += write_char(@end_time,8)
      out += write_char(@producer_app_id,64)
      out += write_char(@producer_app_version,64)
      out += write_char(@user_def,64)
      out += write_dword(@level_reference)
      out += write_char(@post_timer,64)
      out += write_char(@reserved,276)
      out += write_char(@url,1024)
      out += write_char(@tag_text)
      out
    end

  end  
  
  class DataChunk < Chunk
    attr_accessor :tmp_data_file
    
    def self.parse(id, size, file)

      # tmp_data = File.open('./data_chunk.mp2', 'wb')
      tmp_data = Tempfile.open('data_chunk')
      tmp_data.binmode
      
      remaining = size
      while (remaining > 0 && !file.eof?)
        read_bytes = [128, remaining].min
        tmp_data << file.read(read_bytes)
        remaining -= read_bytes
      end
      tmp_data.rewind
      chunk = self.new(id, size, tmp_data)

      return chunk
    end
    
    def self.new_from_file(file)
      tmp_data = Tempfile.open('data_chunk')
      tmp_data.binmode
      File.copy(file.path, tmp_data.path)
      tmp_data.rewind
      self.new('data', File.size(file.path), tmp_data)
    end

    def initialize(id=nil, size=nil, tmp_data_file=nil)
      @id, @size, @tmp_data_file = id, size, tmp_data_file
    end
    
    def data
      f = ''
      if self.tmp_data_file
        NuWav::WaveFile.log "we have a tmp_data_file!"
        self.tmp_data_file.rewind
        f = self.tmp_data_file.read
        self.tmp_data_file.rewind
      else
        NuWav::WaveFile.log "we have NO tmp_data_file!"
      end
      f
    end

    def to_s
      "<chunk type:data (size:#{data.size})/>"
    end
    
    def to_binary
      NuWav::WaveFile.log "data chunk to_binary"
      d = self.data
      NuWav::WaveFile.log "got data size = #{d.size} #{d[0,10]}"
      out = "data" + write_dword(d.size) + d
      out
    end
    
  end
  
end