#!/bin/env ruby

class TarReader

  include File::Constants

  class Entry

    def initialize io
      @io = io
      buf = @io.read(512)
      if buf.unpack('A512').first.empty? then
        buf = @io.read(512)
        throw(:TarReaderEof) if buf.nil?
        throw(:TarReaderEof) if buf.unpack('A512').first.empty?
      end
      throw(:TarReaderEof) if buf.nil?
      @pos = @io.pos
      @name = buf.unpack('A100').first
      @size = buf[124, 12].to_i(8)
      @mtime = buf[136, 12].to_i(8)
      cksum = buf[148, 8].to_i(8)
      xbuf = buf.dup
      xbuf[148, 8] = ' ' * 8
      s = 0
      xbuf.each_byte{|c| s += c}
      raise ArgumentError, "checksum #{s} != #{cksum}" unless s == cksum
      @blocksize = @size - 1
      @blocksize -= @blocksize % 512
      @blocksize += 512
      @io.pos += @blocksize
    end

    attr_reader :name, :mtime, :size

    def read
      # rewind to data head
      @io.pos = @pos
      buf = @io.read(@size)
      @io.pos = @pos + @blocksize
      return buf
    end

  end

  def TarReader::open fnam
    tar = TarReader.new(fnam)
    return tar unless block_given?
    begin
      yield tar
    ensure
      tar.close
    end
    fnam
  end

  def initialize file
    if IO === file then
      @io = file
    else
      @io = File.open(file, RDONLY|BINARY).set_encoding('BINARY')
    end
    @hdr = nil
  end

  def gethdr
    if catch(:TarReaderEof) { @hdr = Entry.new(@io) }
      return true
    end
    nil
  end

  def each_entry
    while gethdr
      yield @hdr
    end
  end

  def close
    @io.close
  end

end

if $0 == __FILE__
  ARGV.each {|arg|
    TarReader.open(arg) {|tar|
      tar.each_entry {|ent|
        t = Time.at(ent.mtime).utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        printf("%8u %20s %s\n", ent.size, t, ent.name)
      }
    }
  }
end
