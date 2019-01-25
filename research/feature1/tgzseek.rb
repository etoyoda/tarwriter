# this works but GzipReader.new(IO) silently killes the Ruby interpreter.
#
require 'rubygems'
require 'zlib'

ARGV.each {|arg|
  puts "# file #{arg}:"
  Zlib::GzipReader.open(arg) { |fp|
    # fp.pos = 0 # NoMethodError
    pos = fp.pos
    while buf = fp.read(512)
      cksum = buf[148, 8].to_i(8)
      xbuf = buf.dup
      xbuf[148, 8] = ' ' * 8
      s = 0
      xbuf.each_byte{|c| s += c}
      if s == cksum then
        name = buf.unpack('A100').first
        size = buf[124, 12].to_i(8)
        blocksize = ((size + 511) / 512) * 512
        fp.read(blocksize)
        puts({:name => name, :size => size, :pos => pos}.inspect)
      end
      pos = fp.pos
    end
  }
}

