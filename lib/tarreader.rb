#!/bin/env ruby

class TarReader

  include File::Constants

  class Entry

    def initialize tar
      @tar = tar
      @pos = @tar.pos
      buf = @tar.read(512)
      if buf.unpack('A512').first.empty? then
        @pos = @tar.pos
        buf = @tar.read(512)
        throw(:TarReaderEof) if buf.nil?
        throw(:TarReaderEof) if buf.unpack('A512').first.empty?
      end
      throw(:TarReaderEof) if buf.nil?
      @name = buf.unpack('A100').first
      @mode = buf[100, 8].to_i(8)
      @uid = buf[108, 8].to_i(8)
      @gid = buf[116, 8].to_i(8)
      @size = buf[124, 12].to_i(8)
      @mtime = buf[136, 12].to_i(8)
      cksum = buf[148, 8].to_i(8)
      xbuf = buf.dup
      xbuf[148, 8] = ' ' * 8
      s = 0
      xbuf.each_byte{|c| s += c}
      raise Errno::EBADF, "checksum #{s} != #{cksum}" unless s == cksum
      @typeflag = buf[156, 1]
      @linkname = buf[157, 100].unpack('A100').first
      @magic = buf[257, 6]
      if /^ustar/ === @magic
        @uname, @gname = buf[265, 64].unpack('A32 A32')
        @devmajor = buf[329, 8].to_i(8)
        @devminor = buf[337, 8].to_i(8)
        @prefix = buf[345, 155].unpack('A155').first
      else
        @uname = @gname = @devmajor = @devminor = @prefix = nil
      end
      @blocksize = @size - 1
      @blocksize -= @blocksize % 512
      @blocksize += 512
    end

    attr_reader :name, :mtime, :size, :mode, :uid, :gid, :typeflag, :linkname, :magic
    attr_reader :devmajor, :devminor, :prefix, :pos

    def uname
      @uname || @uid.to_s
    end

    def gname
      @gname || @gid.to_s
    end

    def mode_symbolic
      [
        case @typeflag when '0', '1' then '-' when '2' then 'l' when '5' then 'd' else @typeflag end,
        (@mode & 0400).zero? ? '-' : 'r',
        (@mode & 0200).zero? ? '-' : 'w',
        (@mode & 0100).zero? ? '-' : 'x',
        (@mode & 0040).zero? ? '-' : 'r',
        (@mode & 0020).zero? ? '-' : 'w',
        (@mode & 0010).zero? ? '-' : 'x',
        (@mode & 0004).zero? ? '-' : 'r',
        (@mode & 0002).zero? ? '-' : 'w',
        (@mode & 0001).zero? ? '-' : 'x'
      ].join
    end

    def end_entry
      @tar.pos = @pos + 512 + @blocksize
    end

    def read
      # rewind to data head
      @tar.pos = @pos + 512
      buf = @tar.read(@size)
      end_entry
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
      @pos = nil
    elsif /\.t?gz$/ === file then
      require 'zlib'
      @io = Zlib::GzipReader.open(file)
      @pos = 0
      $stderr.puts "# TarReader#new GzipReader" if $DEBUG
    else
      @io = File.open(file, RDONLY|BINARY).set_encoding('BINARY')
      @pos = nil
      $stderr.puts "# TarReader#new File" if $DEBUG
    end
  end

  def read size
    $stderr.puts "# TarReader#read(#{size})" if $DEBUG
    @pos += size if @pos
    @io.read(size)
  end

  def pos
    @pos or @io.pos
  end

  def pos= ipos
    $stderr.puts "# TarReader#pos=(#{ipos})" if $DEBUG
    if @pos then
      return if @pos == ipos
      raise Errno::ESPIPE, "cannot seek backword #{@pos} #{ipos}" if ipos < @pos
      span = ipos - @pos
      # this is tuned at tako.toyoda-eizi.net January 2019.
      skipsize = 20 * 512
      (span / skipsize).times { @io.read(skipsize) }
      @io.read(span % skipsize)
      @pos = ipos
    else
      @io.pos = ipos
    end
  end

  def gethdr
    hdr = nil
    return hdr if catch(:TarReaderEof) { hdr = Entry.new(self) }
    hdr
  end

  def each_entry
    while ent = gethdr
      begin
        yield ent
      ensure
        ent.end_entry
      end
    end
  end

  def close
    @io.close
  end

end

if $0 == __FILE__
  byteofs = limit = showpos = nil
  ARGV.each {|arg|
    case arg
    when /^byteofs=(\d+)/i then byteofs = Integer($1)
    when /^limit=(\d+)/i then limit = Integer($1)
    when /^-pos$/i  then showpos = true
    else
      TarReader.open(arg) {|tar|
        tar.pos = byteofs if byteofs
        tar.each_entry {|ent|
          mode = ent.mode_symbolic
          t = Time.at(ent.mtime).strftime('%Y-%m-%d %H:%M')
          puts ent.pos if showpos
          printf("%s %s/%s %5u %16s %s\n", mode, ent.uname, ent.gname, ent.size, t, ent.name)
          if limit
            limit -= 1
            break if limit.zero?
          end
        }
      }
    end
  }
end
