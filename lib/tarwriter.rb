#!/bin/env ruby

##
# This class creates (or appends to) a tar archive.
# API is designed to be compatible with Archive::Tar::Minitar::Writer (https://www.rubydoc.info/gems/minitar/Archive/Tar/Minitar/Writer).

class TarWriter

  include File::Constants

  # opens a POSIX tar file or writing.
  #
  # @param [String] fnam the filename to open.
  # @param [String] mode
  #  'a':: append - created if missing,
  #        and positioned at the EOF record (double NUL records)
  #  'w':: writing - created if missing, and truncated if existing.
  #  'x':: exclusive - similar to 'w' but raises Errno::EEXIST if the file exists.
  # @return [TarWriter] new instance opened, which is yielded if a block is given.

  def TarWriter::open fnam, mode
    tar = TarWriter.new(fnam, mode)
    return tar unless block_given?
    begin
      yield tar
    ensure
      tar.close
    end
    fnam
  end

  # same as TarWriter.open but does not yield the instance.

  def initialize file, mode = 'w'
    @io = if IO === file
    then
      file
    else
      case mode
      when 'x'
        File.open(file, WRONLY|CREAT|EXCL|TRUNC|BINARY).set_encoding('BINARY')
      when 'a'
        File.open(file, RDWR|CREAT|BINARY).set_encoding('BINARY')
      when 'w'
        File.open(file, WRONLY|CREAT|TRUNC|BINARY).set_encoding('BINARY')
      else
        raise "unsupported mode=#{mode}"
      end
    end
    @pos = 0
    find_eof if mode == 'a'
    @blocking_factor = 20
    @pool = []
  end

  # creates a POSIX tar header (String w/BINARY encoding).
  # intended to be used internally, but works without side effect.
  # @param [String] bfnam  filename
  # @param [Integer] size  size of file
  # @param [Integer] time  mtime, seconds since UNIX Era
  # @param [Integer] cksum  optional checksum (NUL filled by default to compute checksum) 
  # @return [String] binary header

  def header bfnam, size, time, cksum = nil
    raise "too long filename #{bfnam}" if bfnam.size >= 100
    mode = sprintf("%07o", 0664)
    uid = gid = sprintf("%07o", 99)
    csize = sprintf("%011o", size)
    cks = cksum ? sprintf("%06o\0", cksum) : ""
    mtime = sprintf("%011o", time)
    typeflag = '0'
    linkname = ''
    magic = 'ustar'
    version = '00'
    uname = gname = 'nobody'
    devmajor = devminor = sprintf('%07o', 0)
    prefix = ''
    fmt = "a100 a8 a8 a8 a12 a12 A8 a1 a100 a6 a2 a32 a32 a8 a8 a155"
    return [bfnam, mode, uid, gid, csize, mtime, cks, typeflag, linkname, magic,
      version, uname, gname, devmajor, devminor, prefix].pack(fmt)
  end

  def add2 fnam, content, time
    STDERR.puts "#big #{fnam} #{content.bytesize}" if $VERBOSE
    bfnam = String.new(fnam, encoding: "BINARY")
    testhdr = header(bfnam, content.bytesize, time)
    cksum = 0
    testhdr.each_byte {|b| cksum += b }
    hdr = header(bfnam, content.bytesize, time, cksum)
    recpos = @io.pos + 512 * @pool.size
    block_write(hdr)
    pure_flush
    fillsize = ((content.bytesize + 511) / 512) * 512 - content.bytesize
    @io.write content
    @io.write [nil].pack(format('a%u', fillsize))
    @pos = @io.pos
    return recpos
  end

  @@bigsize = 0x380000

  # add a file to the TarWriter stream
  # @param [String] fnam  filename
  # @param [String] content  content of the file
  # @param [Time] time  mtime
  # @return [Integer] byte position of the record added.
  # Version 1.2.0 and beore returned the pos of the record *next to* the record added.

  def add fnam, content, time = Time.now
    return add2(fnam, content, time) if content.bytesize > @@bigsize
    bfnam = String.new(fnam, encoding: "BINARY")
    bcontent = String.new(content, encoding: "BINARY")
    return add2(fnam, content, time) if bcontent[bcontent.size-1,1].to_s.empty?
    testhdr = header(bfnam, bcontent.size, time)
    cksum = 0
    testhdr.each_byte {|b| cksum += b }
    hdr = header(bfnam, bcontent.size, time, cksum)
    recpos = @io.pos + 512 * @pool.size
    block_write(hdr)
    ofs = 0
    while blk = bcontent.byteslice(ofs, 512)
      break if blk.empty?
      block_write(blk)
      ofs += 512
    end
    @pos = @io.pos
    return recpos
  end

  # byte position in the TarWriter stream

  attr_reader :pos

  # set the positon at the EOF records

  def find_eof
    @io.seek(0, IO::SEEK_END)
    base = @io.pos
    base -= base % 10240
    loop do
      if base.zero?
        STDERR.puts "empty file" if $DEBUG
        @io.pos = 0
        return 0
      end
      base -= 10240
      @io.pos = base
      STDERR.puts "read #{base}+20b" if $DEBUG
      buf = @io.read(10240)
      19.downto(0) {|i|
        magic = buf[512 * i + 257, 5]
        next unless magic == 'ustar'
        recpos = base + 512 * i
        STDERR.puts "ustar found at #{recpos}" if $DEBUG
        hdr = buf[512 * i, 500]
        cksum = hdr[148, 8].unpack('A*').first.to_i(8)
        hdr[148, 8] = ' ' * 8
        s = 0
        hdr.each_byte{|c| s += c}
        next unless cksum == s
        STDERR.puts "checksum #{s} matches at #{recpos}" if $DEBUG
        size = hdr[124, 12].unpack('A*').first.to_i(8)
        size -= 1
        size -= size % 512
        size += 512
        @io.pos = (recpos + 512 + size)
        @pos = @io.pos
        return @io
      }
    end
  end

  def pure_flush
    @io.write @pool.join
    @pool = []
  end

  def block_write str
    @pool.push [str].pack('a512')
    pure_flush if @pool.size >= @blocking_factor
  end

  def flush
    while not @pool.empty?
      block_write ''
    end
    @io.flush
  end

  def close
    block_write ''
    block_write ''
    flush
    @io.close
  end

  class Folder

    def Folder::open fnam, mode
      folder = Folder.new(fnam, mode)
      return folder unless block_given?
      begin
        yield folder
      ensure
        folder.close
      end
      fnam
    end

    def initialize fnam, mode
      @tar = @dir = nil
      if fnam.nil? then
        @dir = '.'
      elsif File.directory?(fnam) then
        @dir = fnam
      elsif /^mkdir:/ === fnam then
        @dir = $'
        Dir.mkdir(@dir, 0755)
      else
        @tar = TarWriter.new(fnam, mode) 
      end
    end

    def add fnam, content, time = Time.now
      if @tar then
        @tar.add(fnam, content, time)
      else
        path = File.join(@dir, fnam)
        File.open(path, 'w') {|ofp| ofp.write content }
        fnam
      end
    end

    def flush
      @tar.flush if @tar
    end

    def close
      @tar.close if @tar
    end

  end

end

if $0 == __FILE__
  mode = 'x'
  mode = ARGV.shift.sub(/^-/, '') if /^-[xwa]/ === ARGV.first
  ofn = ARGV.shift
  TarWriter.open(ofn, mode) {|tar|
    ARGV.each {|fn|
      File.open(fn) {|ifp|
        tar.add(File.basename(fn), ifp.read)
      }
    }
  }
end
