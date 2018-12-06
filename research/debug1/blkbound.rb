require 'tarwriter'

sizes = [1022, 1023, 1024, 1025]
files = []
sizes.each {|sz|
  fnam = sprintf("b%4u.dat", sz)
  files.push fnam
  File.open(fnam, "wb") {|fp|
    fp.set_encoding("BINARY")
    fp.write('x' * sz)
  }
}

system("tar cvf bstd.tar b1022.dat b1023.dat b1024.dat b1025.dat")

TarWriter.open("blib.tar", "w") {|tar|
  files.each{|fnam|
    File.open(fnam, "rb"){|fp|
      fp.set_encoding("BINARY")
      tar.add(fnam, fp.read)
    }
  }
}
