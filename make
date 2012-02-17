#!/usr/bin/env ruby
require 'metasm'

def cpu; @cpu ||= Metasm::Ia32.new; end
def execls; Metasm::ELF; end

def compile(src, outfile, *args)
	return if File.exist?(outfile) and File.mtime(outfile) > File.mtime(src) and File.mtime(outfile) > File.mtime(__FILE__)
	puts "compiling #{outfile}"
	exe = execls.compile_c_file(cpu, src)
	yield exe if block_given?
	exe.encode_file(outfile, *args)
end

compile 'librubj.c', 'librubj.so', :lib
compile 'main.c', 'rubj'
