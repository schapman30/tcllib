namespace eval ::clay {}
set ::clay::trace 0

proc ::clay::ancestors args {
  set result {}
  set queue {}
  foreach class [lreverse $args] {
    lappend queue $class
  }

  # Rig things such that that the top superclasses
  # are evaluated first
  while {[llength $queue]} {
    set tqueue $queue
    set queue {}
    foreach qclass $tqueue {
      foreach aclass [::info class superclasses $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
    }
    foreach item $tqueue {
      if { $item ni $result } {
        lappend result $item
      }
    }
  }
  return $result
}

proc ::clay::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}

proc ::clay::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trim $var -:] $val
  }
  return $result
}

###
# topic: 4969d897a83d91a230a17f166dbcaede
###
proc ::clay::dynamic_arguments {ensemble method arglist args} {
  set idx 0
  set len [llength $args]
  if {$len > [llength $arglist]} {
    ###
    # Catch if the user supplies too many arguments
    ###
    set dargs 0
    if {[lindex $arglist end] ni {args dictargs}} {
      return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
    }
  }
  foreach argdef $arglist {
    if {$argdef eq "args"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      break
    }
    if {$argdef eq "dictargs"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      ###
      # Perform args processing in the style of clay
      ###
      set dictargs [::clay::args_to_options {*}[lrange $args $idx end]]
      uplevel 1 [list set dictargs $dictargs]
      break
    }
    if {$idx > $len} {
      ###
      # Catch if the user supplies too few arguments
      ###
      if {[llength $argdef]==1} {
        return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
      } else {
        uplevel 1 [list set [lindex $argdef 0] [lindex $argdef 1]]
      }
    } else {
      uplevel 1 [list set [lindex $argdef 0] [lindex $args $idx]]
    }
    incr idx
  }
}

###
# topic: 53ab28ac5c6ee601fe1fe07b073be88e
###
proc ::clay::dynamic_wrongargs_message {arglist} {
  set result ""
  set dargs 0
  foreach argdef $arglist {
    if {$argdef in {args dictargs}} {
      set dargs 1
      break
    }
    if {[llength $argdef]==1} {
      append result " $argdef"
    } else {
      append result " ?[lindex $argdef 0]?"
    }
  }
  if { $dargs } {
    append result " ?option value?..."
  }
  return $result
}

proc ::clay::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {::dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
}

proc ::clay::is_null value {
  return [expr {$value in {{} NULL}}]
}

proc ::clay::leaf args {
  set marker [string index [lindex $args end] end]
  set result [path {*}${args}]
  if {$marker eq "/"} {
    return $result
  }
  return [list {*}[lrange $result 0 end-1] [string trim [string trim [lindex $result end]] /]]
}

proc ::clay::path args {
  set result {}
  foreach item $args {
    set item [string trim $item :./]
    foreach subitem [split $item /] {
      lappend result [string trim ${subitem}]/
    }
  }
  return $result
}

proc ::clay::script_path {} {
  set path [file dirname [file join [pwd] [info script]]]
  return $path
}

proc ::clay::NSNormalize qualname {
  if {![string match ::* $qualname]} {
    set qualname ::clay::classes::$qualname
  }
  regsub -all {::+} $qualname "::"
}

proc ::clay::uuid_generate args {
  return [uuid::uuid generate]
}

namespace eval ::clay {
  variable option_class {}
  variable core_classes {::oo::class ::oo::object}
}
