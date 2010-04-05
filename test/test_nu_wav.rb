require 'helper'
require 'nu_wav'

class TestNuWav < Test::Unit::TestCase
  include NuWav

  def test_parse_wav
    w = WaveFile.parse(File.expand_path(File.dirname(__FILE__) + '/files/test_basic.wav'))
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
  end

  def test_parse_wav_with_bwf_and_cart_chunk
    w = WaveFile.parse(File.expand_path(File.dirname(__FILE__) + '/files/AfropopW_040_SGMT01.wav'))
    assert_equal 6, w.chunks.size
    
    # duration is calculated differently for mpeg and pcm 
    assert_equal 1784, w.duration

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
    assert_equal 1, w.chunks[:fmt].head_mode_ext
    assert_equal 0, w.chunks[:fmt].head_emphasis
    assert_equal 28, w.chunks[:fmt].head_flags

    # fact
    assert_equal 78695424, w.chunks[:fact].samples_number
    
    # mext
    assert_equal 7, w.chunks[:mext].sound_information
    assert_equal 835, w.chunks[:mext].frame_size
    
    # bext
    assert_equal "A=MPEG1L2,F=44100,B=256,M=STEREO,T=CV_PcxTl2NP\r\n", unpad(w.chunks[:bext].coding_history)
    
    # cart
    assert_equal '0101', w.chunks[:cart].version
    assert_equal 'Afropop 070524_Episode on 05/24/2007_sgmt 1', unpad(w.chunks[:cart].title)
    assert_equal 'Georges Collinet', unpad(w.chunks[:cart].artist)
    assert_equal '60314', unpad(w.chunks[:cart].cut_id)
    assert_equal '2007/05/24', unpad(w.chunks[:cart].start_date)
    assert_equal '16:00:00', unpad(w.chunks[:cart].start_time)
    assert_equal '2007/06/24', unpad(w.chunks[:cart].end_date)
    assert_equal '16:00:00', unpad(w.chunks[:cart].end_time)
    assert_equal 'ContentDepot', unpad(w.chunks[:cart].producer_app_id)
    assert_equal '1.0', unpad(w.chunks[:cart].producer_app_version)

    # data
    assert_equal 57040521, w.chunks[:data].size
  end
  
  def unpad(str)
    str.gsub(/\0*$/, '')
  end
  
end
