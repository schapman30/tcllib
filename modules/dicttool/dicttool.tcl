###
# dicttool.tcl
#
# Copyright (c) 2018 Sean Woods
#
# BSD License
###
# @@ Meta Begin
# Package dicttool 1.2
# Meta platform     tcl
# Meta summary      Enhancements to the dict command to support recursive merging
# Meta description  This package adds several list commands and dict commands which
# Meta description  developers find themselves implementing over and over again.
# Meta description  In addition it provides tools to manage recursive dicts in a
# Meta description  clean (and thoroughly regression tested) format.
# Meta category     dict
# Meta subject      dict
# Meta require      {Tcl 8.5}
# Meta author       Sean Woods
# Meta license      BSD
# @@ Meta End

###
# Amalgamated package for dicttool
# Do not edit directly, tweak the source in build/ and rerun
# build.tcl
###
package provide dicttool 1.2
namespace eval ::dicttool {}

###
# START: core.tcl
###
namespace eval ::dicttool {
}
namespace eval ::tcllib {
}
proc ::tcllib::PROC {name arglist body {ninja {}}} {
  if {[info commands $name] ne {}} return
  proc $name $arglist $body
  eval $ninja
}
if {[info commands ::PROC] eq {}} {
  namespace eval ::tcllib { namespace export PROC }
  namespace eval :: { namespace import ::tcllib::PROC }
}
proc ::tcllib::noop args {}
if {[info commands ::noop] eq {}} {
  namespace eval ::tcllib { namespace export noop }
  namespace eval :: { namespace import ::tcllib::noop }
}
proc ::tcllib::putb {buffername args} {
  upvar 1 $buffername buffer
  switch [llength $args] {
    1 {
      append buffer [lindex $args 0] \n
    }
    2 {
      append buffer [string map {*}$args] \n
    }
    default {
      error "usage: putb buffername ?map? string"
    }
  }
}
if {[info command ::putb] eq {}} {
  namespace eval ::tcllib { namespace export putb }
  namespace eval :: { namespace import ::tcllib::putb }
}

###
# END: core.tcl
###
###
# START: dict.tcl
###
PROC ::tcl::dict::getnull {dictionary args} {
  if {[exists $dictionary {*}$args]} {
    get $dictionary {*}$args
  }
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] getnull ::tcl::dict::getnull]
}
PROC ::tcl::dict::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] is_dict ::tcl::dict::is_dict]
}
::tcllib::PROC ::dicttool::is_branch { dict path } {
  set field [lindex $path end]
  if {[string index $field end] eq ":"} {
    return 0
  }
  if {[string index $field 0] eq "."} {
    return 0
  }
  if {[string index $field end] eq "/"} {
    return 1
  }
  return [dict exists $dict {*}$path .]
}
::tcllib::PROC ::dicttool::print {dict} {
  ::set result {}
  ::set level -1
  ::dicttool::_dictputb $level result $dict
  return $result
}
::tcllib::PROC ::dicttool::_dictputb {level varname dict} {
  upvar 1 $varname result
  incr level
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[dicttool::is_branch $dict $field]} {
      putb result "[string repeat "  " $level]$field \{"
      _dictputb $level result $value
      putb result "[string repeat "  " $level]\}"
    } else {
      putb result "[string repeat "  " $level][list $field $value]"
    }
  }
}
proc ::dicttool::sanitize {dict} {
  ::set result {}
  ::set level -1
  ::dicttool::_sanitizeb {} result $dict
  return $result
}
proc ::dicttool::_sanitizeb {path varname dict} {
  upvar 1 $varname result
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[dicttool::is_branch $dict $field]} {
      _sanitizeb [list {*}$path $field] result $value
    } else {
      dict set result {*}$path $field $value
    }
  }
}
proc ::dicttool::canonical {rawpath} {
  set path {}
  set tail [string index $rawpath end]
  foreach element $rawpath {
    set items [split [string trim $element /] /]
    foreach item $items {
      if {$item eq {}} continue
      if {$item eq {.}} continue
      lappend path [string trim ${item} :]/
    }
  }
  if {$tail eq {/}} {
    return $path
  } else {
    return [lreplace $path end end [string trim [lindex $path end] /]]
  }
}
proc ::dicttool::storage {rawpath} {
  set isleafvar 0
  set path {}
  set tail [string index $rawpath end]
  foreach element $rawpath {
    set items [split [string trim $element /] /]
    foreach item $items {
      if {$item eq {}} continue
      lappend path [string trim ${item} :/]
    }
  }
  return $path
}
proc ::dicttool::dictset {varname args} {
  upvar 1 $varname result
  if {[llength $args] < 2} {
    error "Usage: ?path...? path value"
  } elseif {[llength $args]==2} {
    set rawpath [lindex $args 0]
  } else {
    set rawpath  [lrange $args 0 end-1]
  }
  set value [lindex $args end]
  set path [canonical $rawpath]
  set dot .
  set one [string is true 1]
  dict set result $dot $one
  set dpath {}
  foreach item $path {
    set field $item
    lappend dpath [string trim $item /]
    if {[string index $item end] eq "/"} {
      dict set result {*}$dpath $dot $one
    }
  }
  if {[dict is_dict $value] && [dict exists $result {*}$dpath $dot]} {
    dict set result {*}$dpath [::dicttool::merge [dict get $result {*}$dpath] $value]
  } else {
    dict set result {*}$dpath $value
  }
  return $result
}
proc ::dicttool::dictmerge {varname args} {
  upvar 1 $varname result
  set dot .
  set one [string is true 1]
  dict set result $dot $one
  foreach dict $args {
    dict for {f v} $dict {
      set field [string trim $f :/]
      set bbranch [dicttool::is_branch $dict $f]
      if {![dict exists $result $field]} {
        dict set result $field $v
        if {$bbranch} {
          dict set result $field [dicttool::merge $v]
        } else {
          dict set result $field $v
        }
      } elseif {[dict exists $result $field $dot]} {
        if {$bbranch} {
          dict set result $field [dicttool::merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
        }
      }
    }
  }
  return $result
}
proc ::dicttool::merge {args} {
  ###
  # The result of a merge is always a dict with branches
  ###
  set dot .
  set one [string is true 1]
  dict set result $dot $one
  set argument 0
  foreach b $args {
    # Merge b into a, and handle nested dicts appropriately
    if {![dict is_dict $b]} {
      error "Element $b is not a dictionary"
    }
    dict for { k v } $b {
      if {$k eq $dot} {
        dict set result $dot $one
        continue
      }
      set bbranch [is_branch $b $k]
      set field [string trim $k /:]
      if { ![dict exists $result $field] } {
        if {$bbranch} {
          dict set result $field [merge $v]
        } else {
          dict set result $field $v
        }
      } else {
        set abranch [dict exists $result $field $dot]
        if {$abranch && $bbranch} {
          dict set result $field [merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
          if {$bbranch} {
            dict set result $field $dot $one
          }
        }
      }
    }
  }
  return $result
}
::tcllib::PROC ::tcl::dict::isnull {dictionary args} {
  if {![exists $dictionary {*}$args]} {return 1}
  return [expr {[get $dictionary {*}$args] in {{} NULL null}}]
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] isnull ::tcl::dict::isnull]
}

###
# END: dict.tcl
###
###
# START: list.tcl
###
::tcllib::PROC ::ladd {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      set var {}
  }
  foreach item $args {
    if {$item in $var} continue
    lappend var $item
  }
  return $var
}
::tcllib::PROC ::ldelete {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      return
  }
  foreach item [lsort -unique $args] {
    while {[set i [lsearch $var $item]]>=0} {
      set var [lreplace $var $i $i]
    }
  }
  return $var
}
::tcllib::PROC ::lrandom list {
  set len [llength $list]
  set idx [expr int(rand()*$len)]
  return [lindex $list $idx]
}

###
# END: list.tcl
###

namespace eval ::dicttool {
  namespace export *
}

