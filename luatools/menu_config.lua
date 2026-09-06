return {
  mode = "forward",
  modules = {"bool_obfuscate", "num_obfuscate", "str_split", "const_shuffle", "opaque_predicate", "op48_junk", "debug_strip", "antidec"},
  input = "..\\obfuscator\\packed.luac",
  output = "..\\obfuscator\\packed_out.luac",
}
