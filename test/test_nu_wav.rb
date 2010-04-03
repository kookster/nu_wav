require 'helper'

class TestNuWav < Test::Unit::TestCase
  def test_parse_wav
    assert true
  end

  def test_parse_wav_with_bwf
    assert true
  end

  def test_parse_wav_with_bwf_and_cart_chunk
    assert true
  end
end

# if NuWav::DEBUG 
# 
#   wf = NuWav::WaveFile.new
#   # wf.parse('/Users/akuklewicz/dev/testaudio/0330AK_Studded.wav')
#   # puts "wf.duration = #{wf.duration}"
#   # puts "wf = #{wf}"
#   
#   wf.parse('/Users/akuklewicz/dev/workspace/mediajoint/test/fixtures/files/AfropopW_040_SGMT01.wav')
# 
#   puts "--------------------------------------------------------------------------------"
# 
#   wf.write_data_file('/Users/akuklewicz/dev/workspace/mediajoint/test/fixtures/files/AfropopW_040_SGMT01.mp2')
# 
#   # wf.to_file('AK_FreshA05_160_SGMT02')
#   # wf.parse('AK_FreshA05_160_SGMT02.wav')
#   
#   puts "--------------------------------------------------------------------------------"
#   # 
# 
#   wv = NuWav::WaveFile.from_mpeg('/Users/akuklewicz/dev/workspace/mediajoint/test/fixtures/files/AK_AfropopW_040_SGMT01.mp2')
#   wv.to_file('AK_AfropopW_040_SGMT01_to_file_test.wav')
#   
#   puts "--------------------------------------------------------------------------------"
# 
#   wf = NuWav::WaveFile.new
#   wf.parse('AK_AfropopW_040_SGMT01_to_file_test.wav')
#   
# 
#   
# end
