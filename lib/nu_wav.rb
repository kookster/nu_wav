# http://www.prss.org/contentdepot/automation_specifications.cfm
# Bill Kelly <billk <at> cts.com> http://article.gmane.org/gmane.comp.lang.ruby.general/43110
# BWF intro  http://en.wikipedia.org/wiki/Broadcast_Wave_Format
# BWF basics http://tech.ebu.ch/docs/tech/tech3285.pdf
# BWF mpeg   http://tech.ebu.ch/docs/tech/tech3285s1.pdf

require 'rubygems'
require 'mp3info'
require 'date'
require 'tempfile'
require 'fileutils'

require "nu_wav/version"
require "nu_wav/wave_file"

module NuWav

  DEBUG = ENV['NU_WAV_DEBUG']

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

end