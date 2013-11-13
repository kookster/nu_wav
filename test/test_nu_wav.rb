require 'helper'
require 'nu_wav'
require 'tempfile'

class TestNuWav < Test::Unit::TestCase
  include NuWav

  def test_parse_wav
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in kilobytes
    # puts "begin test: #{memory_usage/1024} mb"
    w = WaveFile.parse(File.expand_path(File.dirname(__FILE__) + '/files/test_basic.wav'))
    # puts w
    assert_equal 4260240, w.header.size

    assert_equal 2, w.chunks.size
    assert_equal 48, w.duration

    fmt = w.chunks[:fmt]
    assert_equal 1, fmt.number_of_channels
    assert_equal 44100, fmt.sample_rate
    assert_equal 88200, fmt.byte_rate
    assert_equal 2, fmt.block_align
    assert_equal 16, fmt.sample_bits
    
    data = w.chunks[:data]
    assert_equal 4260204, data.size

    File.delete('test_out.wav') rescue nil
    w.to_file('test_out.wav')
    assert File.exists?('test_out.wav')
    assert_equal File.size('test_out.wav'), 4260250

    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in kilobytes
    # puts "end of test: #{memory_usage/1024} mb"
    File.delete('test_out.wav')    
  end

  def test_parse_wav_with_bwf_and_cart_chunk
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in kilobytes
    # puts "begin test: #{memory_usage/1024} mb"
    
    w = WaveFile.parse(File.expand_path(File.dirname(__FILE__) + '/files/test_bwf.wav'))
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in kilobytes
    # puts "after parse: #{memory_usage/1024} mb"
    
    assert_equal 6, w.chunks.size
    
    # duration is calculated differently for mpeg and pcm 
    assert_equal 60, w.duration

    # fmt
    assert_equal 2, w.chunks[:fmt].number_of_channels
    assert_equal 44100, w.chunks[:fmt].sample_rate
    assert_equal 32000, w.chunks[:fmt].byte_rate
    assert_equal 835, w.chunks[:fmt].block_align
    assert_equal 65535, w.chunks[:fmt].sample_bits
    assert_equal 22, w.chunks[:fmt].extra_size
    assert_equal 2, w.chunks[:fmt].head_layer
    assert_equal 256000, w.chunks[:fmt].head_bit_rate
    assert_equal 1, w.chunks[:fmt].head_mode
    assert_equal 0, w.chunks[:fmt].head_mode_ext
    assert_equal 1, w.chunks[:fmt].head_emphasis
    assert_equal 30, w.chunks[:fmt].head_flags

    # fact
    assert_equal 2646144, w.chunks[:fact].samples_number
    
    # mext
    assert_equal 5, w.chunks[:mext].sound_information
    assert_equal 835, w.chunks[:mext].frame_size
    
    # bext
    assert_equal "A=MPEG1L2,F=44100,B=256,M=stereo,T=PRX", unpad(w.chunks[:bext].coding_history)
    
    # cart
    assert_equal '0101', w.chunks[:cart].version
    assert_equal "5: 415: Sound Opinions Show, 11/8/2013", unpad(w.chunks[:cart].title)
    assert_equal "Sound Opinions", unpad(w.chunks[:cart].artist)
    assert_equal '30014', unpad(w.chunks[:cart].cut_id)
    assert_equal '2013/11/08', unpad(w.chunks[:cart].start_date)
    assert_equal '00:00:00', unpad(w.chunks[:cart].start_time)
    assert_equal '2013/11/14', unpad(w.chunks[:cart].end_date)
    assert_equal '23:59:59', unpad(w.chunks[:cart].end_time)
    assert_equal 'PRX', unpad(w.chunks[:cart].producer_app_id)
    assert_equal '1.0', unpad(w.chunks[:cart].producer_app_version)

    # data
    assert_equal 1917995, w.chunks[:data].size
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in kilobytes
    # puts "end of test: #{memory_usage/1024} mb"
  end
  
  def test_from_mpeg
    w = WaveFile.from_mpeg(File.expand_path(File.dirname(__FILE__) + '/files/test.mp2'))

    File.delete('test_from_mpeg.wav') rescue nil
    w.to_file('test_from_mpeg.wav')
    assert File.exists?('test_from_mpeg.wav')
    assert_equal File.size('test_from_mpeg.wav'), 182522
    File.delete('test_from_mpeg.wav')


    File.delete('test_from_mpeg.mp2') rescue nil
    w.write_data_file('test_from_mpeg.mp2')
    assert File.exists?('test_from_mpeg.mp2')
    assert_equal File.size('test_from_mpeg.mp2'), 179712
    File.delete('test_from_mpeg.mp2')
  end
  
  def unpad(str)
    str.gsub(/\0*$/, '')
  end
  
end
