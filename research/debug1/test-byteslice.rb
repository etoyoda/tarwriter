bcontent = 'x'.force_encoding('BINARY') * 1024
ofs = 0
    while blk = bcontent.byteslice(ofs, 512)
      p [ofs, blk.size]
      ofs += 512
    end
