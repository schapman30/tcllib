set here [file dirname [file normalize [file join [pwd] [info script]]]]

set version 0.11
set module [file tail $here]

set fout [open [file join $here [file tail $module].tcl] w]
fconfigure $fout -translation lf
dict set map %module% $module
dict set map %version% $version

puts $fout [string map $map {###
# Amalgamated package for %module%
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package provide %module% %version%
namespace eval ::%module% {}
}]

# Track what files we have included so far
set loaded {}
# These files must be loaded in a particular order

###
# Load other module code that this module will need
###
foreach {omod files} {
  httpwget wget.tcl
} {
  foreach fname $files {
    set file [file join $here .. $omod $fname]
    set fin [open [file join $here src $file] r]
    puts $fout "###\n# START: [file join $omod $fname]\n###"
    puts $fout [read $fin]
    close $fin
    puts $fout "###\n# END: [file join $omod $fname]\n###"
  }
}

foreach file {
  setup.tcl
  buildutil.tcl
  fileutil.tcl
  installutil.tcl
  makeutil.tcl
  {class metaclass.tcl}

  {class toolset baseclass.tcl}
  {class toolset gcc.tcl}
  {class toolset msvc.tcl}

  {class target.tcl}
  {class object.tcl}
  {class dynamic.tcl}
  {class product.tcl}
  {class module.tcl}

  {class project baseclass.tcl}
  {class project library.tcl}
  {class project tclkit.tcl}

  {class distro baseclass.tcl}
  {class distro snapshot.tcl}
  {class distro fossil.tcl}
  {class distro git.tcl}

  {class subproject baseclass.tcl}
  {class subproject binary.tcl}
  {class subproject core.tcl}

  {class tool.tcl}

} {
  lappend loaded $file
  set fin [open [file join $here src {*}$file] r]
  puts $fout "###\n# START: [file join $file]\n###"
  puts $fout [read $fin]
  close $fin
  puts $fout "###\n# END: [file join $file]\n###"
}


# Provide some cleanup and our final package provide
puts $fout [string map $map {
namespace eval ::%module% {
  namespace export *
}
}]
close $fout

###
# Build our pkgIndex.tcl file
###
set fout [open [file join $here pkgIndex.tcl] w]
fconfigure $fout -translation lf
puts $fout [string map $map {# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded %module% %version% [list source [file join $dir %module%.tcl]]
}]
close $fout
