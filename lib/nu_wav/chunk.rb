module NuWav
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
      (@raw[start..(start+length-1)] || '').strip
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
      val = val.to_s
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
      @out_cue =              read_char(388,64)
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
      out += write_char(@out_cue,64)
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
      tmp_data = NuWav.temp_file('data_chunk', true)
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
      tmp_data = NuWav.temp_file('data_chunk', true)
      tmp_data.binmode
      FileUtils.cp(file.path, tmp_data.path)
      tmp_data.rewind
      self.new('data', File.size(tmp_data.path).to_s, tmp_data)
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
