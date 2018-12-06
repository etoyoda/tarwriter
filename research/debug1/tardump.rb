def tartest fp
  while true
    pos = fp.pos
    bpos = pos / 512
    blk = fp.read(512)
    break if blk.nil?
    hdr = blk[0, 500]
    magic = hdr[257, 5]
    printf("%d: magic=%s\n", bpos, magic.inspect)
    cksum = hdr[148, 8].unpack('A*').first.to_i(8)
    hdr[148, 8] = ' ' * 8
    s = 0
    hdr.each_byte{|c| s += c}
    printf("%d: checksum %d != %d\n", bpos, cksum, s) if s != cksum
    bsize = size = hdr[124, 12].unpack('A*').first.to_i(8)
    size -= 1
    size -= size % 512
    size += 512
    printf("%d: bytesize=%d size=%d\n", bpos, bsize, size / 512)
    fp.pos = pos + size + 512
  end
end

ARGV.each{|file|
  File.open(file, "rb") {|fp|
    fp.set_encoding('BINARY')
    tartest(fp)
  }
}
