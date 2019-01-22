def tarfix ifp, ofp
  zeroblk = "\0" * 512
  nreset = 0
  nskip = 0
  while true
    pos = ifp.pos
    bpos = pos / 512
    blk = ifp.read(512)
    break if blk.nil?
    if blk == zeroblk then
      nskip += 1
      next
    end
    if nskip > 0 then
      printf("%u: reset nskip %u\n", bpos, nskip)
      nreset += nskip
      nskip = 0
    end
    # check the header
    hdr = blk[0, 500]
    magic = hdr[257, 5]
    cksum = hdr[148, 8].unpack('A*').first.to_i(8)
    hdr[148, 8] = ' ' * 8
    s = 0
    hdr.each_byte{|c| s += c}
    if s != cksum
      printf("%d: checksum %d != %d\n", bpos, cksum, s)
      exit 1
    else
      bsize = size = hdr[124, 12].unpack('A*').first.to_i(8)
      size -= 1
      size -= size % 512
      size += 512
      ofp.write(blk)
      ofp.write(ifp.read(size))
    end
  end
  printf("%u: nreset %u nskip %u\n", bpos, nreset, nskip)
  (nreset + nskip).times { ofp.write(zeroblk) }
end

infnam, outfnam = ARGV
File.open(infnam, "rb") {|ifp|
  ifp.set_encoding('BINARY')
  File.open(outfnam, "wb") {|ofp|
    ofp.set_encoding('BINARY')
    tarfix(ifp, ofp)
  }
}
