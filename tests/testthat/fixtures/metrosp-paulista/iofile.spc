series{
  title = "iofile"
  file = "@DATA@"
  format = "datevalue"
  period = 12
}

transform{
  function = auto
  print = aictransform
}

seats{
  noadmiss = yes
  save = (s10 s11 s12 s13 s16 s18)
}

regression{
  aictest = (td easter)
}

outlier{

}

automdl{
  print = bestfivemdl
}

estimate{
  save = (model estimates residuals)
}

spectrum{
  print = qs
}
