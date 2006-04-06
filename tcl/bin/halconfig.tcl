#!/bin/sh
# export HALCMD \
export HALCMD 
# we need to find the tcl dir, it was exported from emc \
export EMC2_TCL_DIR
# and some apps need the emc2_bin_dir, so export that too \
export REALTIME
# the next line restarts using emcsh \
exec $EMC2_EMCSH "$0" "$@"

###############################################################
# Description:  halconfig.tcl
#               This file, shows a running hal configuration
#               and has menu for modifying and tuning
#
#  Author: Raymond E Henry
#  License: GPL Version 2
#
#  Copyright (c) 2006 All rights reserved.
#
#  Last change:
# $Revision$
# $Author$
# $Date$
###############################################################
# Script accesses HAL through two modes halcmd show xxx for show
# and open halcmd -skf for building tree, watch, edit, and such 
###############################################################

#first define some default directories
set TCLBIN tcl/bin
set TCLSCRIPTS tcl/scripts
set TCLDIR tcl
set REALTIME scripts/realtime

# default location for halcmd is in ./bin/
# if this file is needed to run a different location of halcmd
# the env(HALCMD) will hold the absolute path to it
set HALCMD bin/halcmd

if {[info exists env(EMC2_TCL_DIR)]} {
    set TCLBIN $env(EMC2_TCL_DIR)
    set TCLSCRIPTS $env(EMC2_TCL_DIR)
    set TCLBIN $TCLBIN/bin
    set TCLSCRIPTS $TCLSCRIPTS/scripts
    set TCLDIR $env(EMC2_TCL_DIR)
}

if {[info exists env(REALTIME)]} {
    set REALTIME $env(REALTIME)
}

# get the absolute path to HALCMD if it exists
if {[info exists env(HALCMD)]} {
    set HALCMD $env(HALCMD)
}

package require msgcat
if ([info exists env(LANG)]) {
    msgcat::mclocale $env(LANG)
    msgcat::mcload $TCLDIR/../src/po
    #FIXME add location for installed lang files
}

package require BWidget

#----------open channel to halcmd ----------

proc openHALCMD {} {
    global fid HALCMD
    set fid [open "|$HALCMD -skf" "r+"]
    fconfigure $fid -buffering line -blocking on
    gets $fid
    fileevent $fid readable {getsHAL}
}

proc exHAL {argv} {
    global fid chanflag returnstring
    set chanflag rd
    puts $fid "${argv}"
#    puts "Proc exHAL, fid = '$fid', argv = '$argv'"
    vwait chanflag
    set tmp $returnstring
    set returnstring ""
    return $tmp
}

# getsHAL appends lines to returnstring until it receives a line with just 
# a percent sign "%" on it 
# Once the % is received, the global var chanflag is set to "wr"
set returnstring ""
proc getsHAL {} {
    global fid chanflag returnstring
    gets $fid tmp
    if {$tmp != "\%"} {
        append returnstring $tmp
    } else {
        set chanflag wr
    }
}
openHALCMD
#
#----------end of open halcmd----------

# add a few default characteristics to the display
foreach class { Button Checkbutton Entry Label Listbox Menu Menubutton \
    Message Radiobutton Scale } {
    option add *$class.borderWidth 1  100
}

set numaxes [emc_ini "AXES" "TRAJ"]

# Find the name of the ini file used for this run.
set thisinifile "$EMC_INIFILE"
set thisconfigdir [file dirname $thisinifile]


#----------start toplevel----------
#

wm title . [msgcat::mc "HAL Configuration"]
wm protocol . WM_DELETE_WINDOW tk_
set masterwidth 700
set masterheight 450
# set fixed size for configuration display and center
set xmax [winfo screenwidth .]
set ymax [winfo screenheight .]
set x [expr ($xmax - $masterwidth )  / 2 ]
set y [expr ($ymax - $masterheight )  / 2]
wm geometry . "${masterwidth}x${masterheight}+$x+$y"

# trap mouse click on window manager delete and ask to save
wm protocol . WM_DELETE_WINDOW askKill
proc askKill {} {
    global configdir
    set tmp [tk_messageBox -icon question -type yesnocancel \
        -message [msgcat::mc "Would you like to save your configuration before you exit?"]]
    switch -- $tmp {
        yes {saveHAL $configdir ; killHalConfig}
        no {killHalConfig}
        cancel {return}
    }
}

# clean up a possible problems during shutdown
proc killHalConfig {} {
    global fid
    if {[info exists fid] && $fid != ""} {
        catch flush $fid
        catch close $fid
    }
    exit
    destroy .
}

set main [frame .main ]
pack $main -fill both -expand yes

# build frames from left side
set tf [frame $main.maint]
set top [NoteBook $main.note]

# Each mode has a unique set of widgets inside tab
set showhal [$top insert 0 ps -text [msgcat::mc "Show"] -raisecmd {showMode showhal} ]
set watchhal [$top insert 1 pw -text [msgcat::mc "Watch"] -raisecmd {showMode watchhal}]
set modifyhal [$top insert 2 pm -text [msgcat::mc "Modify"] -raisecmd {showMode modifyhal}]

# Each axis has its own tab 
for {set j 0} {$j<$numaxes} {incr j} {
    set af$j [$top insert [expr $j+3] page$j \
        -text "[msgcat::mc "Tune"] $j"  -raisecmd [] ]
}

# use place manager to fix locations of frames within top
place configure $tf -in $main -x 0 -y 0 -relheight 1 -relwidth .3
place configure $top -in $main -relx .3 -y 0 -relheight 1 -relwidth .7

# slider process is used for several widgets
proc sSlide {f a b} {
    $f.sc set $a $b
}

# Build menu
# fixme clean up the underlines so they are unique under each set
set menubar [menu $top.menubar -tearoff 0]
set filemenu [menu $menubar.file -tearoff 0]
    $menubar add cascade -label [msgcat::mc "File"] \
            -menu $filemenu -underline 0
        $filemenu add command -label [msgcat::mc "Run Hal"] \
            -command {} -underline 0 -state disabled
        $filemenu add command -label [msgcat::mc "Refresh"] \
            -command {refreshHAL} -underline 0
        $filemenu add command -label [msgcat::mc "Save"] \
            -command {saveHAL save} -underline 0 -state disabled
        $filemenu add command -label [msgcat::mc "Save As"] \
            -command {saveHAL saveas} -underline 0 -state disabled
        $filemenu add command -label [msgcat::mc "Save and Exit"] \
            -command {saveHAL saveandexit} -underline 1 -state disabled
        $filemenu add command -label [msgcat::mc "Exit"] \
            -command {killHalConfig} -underline 0
set viewmenu [menu $menubar.view -tearoff 0]
    $menubar add cascade -label [msgcat::mc "View"] \
            -menu $viewmenu -underline 0
        $viewmenu add command -label [msgcat::mc "Expand Tree"] \
            -command {showNode {open}} -underline 1
        $viewmenu add command -label [msgcat::mc "Collapse Tree"] \
            -command {showNode {close}} -underline 1
        $viewmenu add separator
        $viewmenu add command -label [msgcat::mc "Expand Pins"] \
            -command {showNode {pin}} -underline 1
        $viewmenu add command -label [msgcat::mc "Expand Parameters"] \
            -command {showNode {param}} -underline 1
        $viewmenu add command -label [msgcat::mc "Expand Signals"] \
            -command {showNode {sig}} -underline 1
        $viewmenu add separator
        $viewmenu add command -label [msgcat::mc "Erase Watch"] \
            -command {watchReset all} -underline 1
# set settingsmenu [menu $menubar.settings -tearoff 0]
#    $menubar add cascade -label [msgcat::mc "Settings"] \
            -menu $settingsmenu -underline 0
#        $settingsmenu add radiobutton -label [msgcat::mc "Show"] \
            -variable workmode -value showhal -underline 0 \
            -command {showMode showhal }
           
set helpmenu [menu $menubar.help -tearoff 0]
    $menubar add cascade -label [msgcat::mc "Help"] \
            -menu $helpmenu -underline 0
        $helpmenu add command -label [msgcat::mc "About"] \
            -command {showHelp about} -underline 0
        $helpmenu add command -label [msgcat::mc "Main"] \
            -command {showHelp main} -underline 0
. configure -menu $menubar

# build the tree widgets left side
set treew [Tree $tf.t  -width 10 -yscrollcommand "sSlide $tf" ]
set str $tf.sc
scrollbar $str -orient vert -command "$treew yview"
pack $str -side right -fill y
pack $treew -side right -fill both -expand yes
$treew bindText <Button-1> {workMode   }

#----------tree widget handlers----------
# a global var -- treenodes -- holds the names of existing nodes
# nodenames are the text applied to the toplevel tree nodes
# they could be internationalized here but the international name
# must contain no whitespace.  I'm not certain how to do that.
set nodenames {Components Pins Parameters Signals Functions Threads}

# searchnames is the real name to be used to reference
set searchnames {comp pin param sig funct thread}
set signodes {X Y Z A "Spindle"}

set treenodes ""
proc refreshHAL {} {
    global treew treenodes oldvar
    set tmpnodes ""
    # look through tree for nodes that are displayed
    foreach node $treenodes {
        if {[$treew itemcget $node -open]} {
            lappend tmpnodes $node
        }
    }
    # clean out the old tree
    $treew delete [$treew nodes root]
    # reread hal and make new nodes
    listHAL
    # read opennodes and set tree state if they still exist
    foreach node $tmpnodes {
        if {[$treew exists $node]} {
            $treew opentree $node no
        }
    }
    showHAL $oldvar
}

# listhal gets $searchname stuff
# and calls makeNodeX with list of stuff found.
proc listHAL {} {
    global searchnames nodenames
    set i 0
    foreach node $searchnames {
        writeNode "$i root $node [lindex $nodenames $i] 1"
        set ${node}str [exHAL "list $node" ]
#        puts "this is $node --\n [set ${node}str]"
        switch -- $node {
            pin {-}
            param {
                makeNodeP $node [set ${node}str]
            }
            sig {
                makeNodeSig $sigstr
            }
            comp {-}
            funct {-}
            thread {
                makeNodeOther $node [set ${node}str]
            }
            default {}
        }
    
    incr i
    }
}

proc makeNodeP {which pstring} {
    global treew 
    # make an array to hold position counts
    array set pcounts {1 1 2 1 3 1 4 1 5 1}
    # consider each listed element
    foreach p $pstring {
        set elementlist [split $p "." ]
        set lastnode [llength $elementlist]
        set i 1
        foreach element $elementlist {
            switch $i {
                1 {
                    set snode "$which+$element"
                    if {! [$treew exists "$snode"] } {
                        set leaf [expr $lastnode - 1]
                        set j [lindex [array get pcounts 1] end]
                        writeNode "$j $which $snode $element $leaf"
                        array set pcounts "1 [incr j] 2 1 3 1 4 1 5 1"
                        set j 0
                    }
                    set i 2
                }
                2 {
                    set ssnode "$snode.$element"
                    if {! [$treew exists "$ssnode"] } {
                        set leaf [expr $lastnode - 2]
                        set j [lindex [array get pcounts 2] end]
                        writeNode "$j $snode $ssnode $element $leaf"
                        array set pcounts "2 [incr j] 3 1 4 1 5 1"
                        set j 0
                    }
                    set i 3
                }
                3 {
                    set sssnode "$ssnode.$element"
                    if {! [$treew exists "$sssnode"] } {
                        set leaf [expr $lastnode - 3]
                        set j [lindex [array get pcounts 3] end]
                        writeNode "$j $ssnode $sssnode $element $leaf"
                        array set pcounts "3 [incr j] 4 1 5 1"
                        set j 0
                    }
                    set i 4
                }
                4 {
                    set ssssnode "$sssnode.$element"
                    if {! [$treew exists "$ssssnode"] } {
                        set leaf [expr $lastnode - 4]
                        set j [lindex [array get pcounts 4] end]
                        writeNode "$j $sssnode $ssssnode $element $leaf"
                        array set pcounts "4 [incr j] 5 1"
                        set j 0
                    }
                    set i 5
                }
                5 {
                    set sssssnode "$ssssnode.$element"
                    if {! [$treew exists "$sssssnode"] } {
                        set leaf [expr $lastnode - 5]
                        set j [lindex [array get pcounts 5] end]
                        writeNode "$j $ssssnode $sssssnode $element $leaf"
                        array set pcounts "5 [incr j]"
                        set j 0
                    }
                }
              # end of node making switch
            }
           # end of element foreach
         }
        # end of param foreach
    }
    # empty the counts array in preparation for next proc call
    array unset pcounts {}
}

# signal node assumes more about HAL than pins or params.
# For this reason the hard coded variable signodes
proc makeNodeSig {sigstring} {
    global treew signodes
    # build sublists dotstring, each signode element, and remainder
    foreach nodename $signodes {
        set nodesig$nodename ""
    }
    set dotsig ""
    set remainder ""
    foreach tmp $sigstring {
        set i 0
        if {[string match *.* $tmp]} {
            lappend dotsig $tmp
            set i 1
        }
   
        foreach nodename $signodes {
            if {[string match *$nodename* $tmp]} {
                lappend nodesig$nodename $tmp
                set i 1
            }
        }
        if {$i == 0} {
            lappend remainder $tmp
        }
    }
    set i 0
    # build the signode named nodes and leaves
    foreach nodename $signodes {
        set tmpstring [set nodesig$nodename]
        if {$tmpstring != ""} {
            set snode "sig+$nodename"
            writeNode "$i sig $snode $nodename 1"
            incr i
            set j 0
            foreach tmp [set nodesig$nodename] {
                set ssnode sig+$tmp
                writeNode "$j $snode $ssnode $tmp 0"
                incr j
            }
        }
    }
    set j 0
    # build the linkpp based signals just below signode
    foreach tmp $dotsig {
        set tmplist [split $tmp "."]
        set tmpmain [lindex $tmplist 0]
        set tmpname [lindex $tmplist end] 
        set snode sig+$tmpmain
        if {! [$treew exists "$snode"] } {
            writeNode "$i sig $snode $tmpmain 1"
            incr i
        }
        set ssnode sig+$tmp
        writeNode "$j $snode $ssnode $tmp 0"
        incr j
    }
    # build the remaining leaves at the bottom of list
    foreach tmp $remainder {
        set snode sig+$tmp
        writeNode "$i sig $snode $tmp 0"
        incr i
    }

}

proc makeNodeOther {which otherstring} {
    global treew
    set i 0
    foreach element $otherstring {
        set snode "$which+$element"
        if {! [$treew exists "$snode"] } {
            set leaf 0
            writeNode "$i $which $snode $element $leaf"
        }
        incr i
    }
}

# writeNode handles tree node insertion for makeNodeX
# builds a global list -- treenodes -- but not leaves
proc writeNode {arg} {
    global treew treenodes
    scan $arg {%i %s %s %s %i} j base node name leaf
    $treew insert $j  $base  $node -text $name
    if {$leaf > 0} {
        lappend treenodes $node
    }
}

proc showNode {which} {
    global treew
    switch -- $which {
        open {-}
        close {
            foreach type {pin param sig} {
                $treew ${which}tree $type
            }
        }
        pin {-}
        param {-}
        sig {
            foreach type {pin param sig} {
                $treew closetree $type
            }
            $treew opentree $which
            $treew see $which
        }
        default {}
    }
    focus -force $treew
}

#
#----------end of tree building processes----------

set axnum 0
set numaxes 4
set oldvar "zzz"
# build show mode right side
proc makeShow {} {
    global showhal disp showtext
    set what full
    if {$what == "full"} {
        set stf [frame $showhal.t]
        set disp [text $stf.tx  -wrap word -takefocus 0 -state disabled \
            -relief flat -borderwidth 0 -height 26 -yscrollcommand "sSlide $stf"]
        set stt $stf.sc
        scrollbar $stt -orient vert -command "$disp yview"
        pack $stt -side right -fill both -expand yes
        pack $disp -side right -fill both -expand yes
        set seps [frame $showhal.sep -bg black -borderwidth 2]
        set cfent [frame $showhal.b]
        set lab [label $cfent.label -text [msgcat::mc "Enter HAL command :"] ]
        set com [entry $cfent.entry -textvariable halcommand]
        bind $com <KeyPress-Return> {showEx $halcommand}
        set ex [button $cfent.execute -text [msgcat::mc "Execute"] \
            -command {showEx $halcommand} ]
        set showtext [text $showhal.txt -height 2  -borderwidth 2 -relief groove ]
        pack $lab -side left -padx 5 -pady 3 
        pack $com -side left -fill x -expand yes -pady 3
        pack $ex -side left -padx 5 -pady 3
        pack $stf $seps $cfent $showtext -side top -fill both -expand yes
    }
}

proc makeWatch {} {
    global cisp watchhal
    set cisp [canvas $watchhal.c ]
    pack $cisp -side right -fill both -expand yes
}

proc makeModify {} {
    global modifyhal modtext focusname mcsets
    set mcsets { {loadrt 1} {unloadrt 1} {addf 1} {delf 1} {newsig 2} {delsig 1} \
        {linkpp 2} {linkps 2} {linksp 2} {unlinkp 1}  }
    set moddisplay [frame $modifyhal.textframe ]
    set modtext [text $moddisplay.text -width 40 -height 8 -wrap word \
        -takefocus 0 -relief groove]
    pack $modtext -side bottom -fill both -expand yes
    set j 1
    foreach cset $mcsets {
        set halmodcmd ""
        scan $cset { %s %i } commandname numvars
        if {$numvars == 2} {
            set colspan 1
        } else {
            set colspan 2
        }
        label $modifyhal.$commandname -text "$commandname: " -anchor w
        grid configure $modifyhal.$commandname -row $j -column 0 -sticky nsew
        for {set i 1} {$i <= $numvars} {incr i} {
            set $commandname$i ""
            entry $modifyhal.e$commandname$i -textvariable $commandname$i \
                -bg white
            bind $modifyhal.e$commandname$i <Button-1> \
                "copyVar $modifyhal.e$commandname$i"
            grid configure $modifyhal.e$commandname$i -row $j -column $i \
                -columnspan $colspan -sticky nsew
        }
        if {$i == "2"} {
            set tmp [subst {$commandname \$${commandname}1}]
        } else {
            set tmp [subst {$commandname \$${commandname}1 \$${commandname}2}]
        }
        button $modifyhal.b$commandname -text [msgcat::mc "Execute"] \
            -command [subst {modHAL "$tmp"}]
        grid configure $modifyhal.b$commandname -row $j -column 3 -sticky nsew
        incr j
    }
    grid configure $moddisplay -row $j -column 0 -columnspan 4 -sticky nsew
}

# FIXME set these for the new page displays.
array set modtypes {
    comp "$modifyhal.eloadrt1 $modifyhal.eunloadrt1"
    funct "$modifyhal.eaddf1 $modifyhal.edelf1"
    thread "$modifyhal.eaddf1"
    pin "$modifyhal.elinkpp1 $modifyhal.elinkpp2 $modifyhal.elinkps1 \
        $modifyhal.elinksp2 $modifyhal.eunlinkp1"
    sig "$modifyhal.elinkps2 $modifyhal.elinksp1 $modifyhal.enewsig1 \
        $modifyhal.edelsig1"
}

set modlist "$modifyhal.eloadrt1 $modifyhal.eunloadrt1 $modifyhal.eaddf1 $modifyhal.edelf1 $modifyhal.elinkpp1 $modifyhal.elinkpp2 $modifyhal.elinkps1 $modifyhal.elinksp2 $modifyhal.elinkps2 $modifyhal.elinksp1 $modifyhal.enewsig1 $modifyhal.edelsig1 $modifyhal.eunlinkp1"


# FIXME allow for more than one tunable system
# FIXME get the number of axes from ini if available

proc makeTune {} {
    global axisentry activeAxis main top initext HALCMD sectionarray thisconfigdir
    global logo numaxes EMC_INIFILE namearray commandarray valarray thisinifile
    for {set i 0} {$i<$numaxes} {incr i} {
        global af$i
    }
 
    # Make a text widget to hold the ini file and
    # put a copy of the inifile in this text widget
    set initext [text $top.initext]
    $initext config -state normal
    $initext delete 1.0 end
    if {[catch {open $thisinifile} programin]} {
        return 
    } else {
        $initext insert end [read $programin]
        catch {close $programin}
    }

    # setup array with section names and line numbers
    # sections are without [] around
    # line numbering starts from 1 as do unix line numbers
    array set sectionarray {}
    scan [$initext index end] %d nl
    set inilastline $nl
    for {set i 1} {$i < $nl} {incr i} {
        if { [$initext get $i.0] == "\[" } {
            set inisectionname [$initext get $i.1 $i.end]
            set inisectionname [string trimright $inisectionname \] ]
            array set sectionarray "$inisectionname $i"
        }
    }

    # Find the HALFILE names between HAL and TRAJ
    set startline $sectionarray(HAL)
    set endline $sectionarray(TRAJ)
    set halfilelist ""
    for {set i $startline} {$i < $endline} {incr i} {
        set thisstring [$initext get $i.0 $i.end]
        if { [lindex $thisstring 0] == "HALFILE" } {
            set thishalname [lindex $thisstring end]
            lappend halfilelist $thisconfigdir/$thishalname
        }
    }

    # make a second text widget for scratch writing
    set scratchtext [text $top.scratchtext]

    # New halconfig allows for ini reads from most any location
    # For axis tuning search each .hal file for AXIS
    foreach fname $halfilelist {
        $scratchtext config -state normal
        $scratchtext delete 1.0 end
        if {[catch {open $fname} programin]} {
            return
        } else {
            $scratchtext insert end [read $programin]
            catch {close $programin}
        }
       
        # find the ini references in this hal and build widgets        
        scan [$scratchtext index end] %d nl
        for {set i 1} {$i < $nl} {incr i} {
            set tmpstring [$scratchtext get $i.0 $i.end]
            if {[lsearch -regexp $tmpstring AXIS] > -1} { 
                for {set j 0} {$j < $numaxes} {incr j} {
                    if {[lsearch -regexp $tmpstring AXIS_$j] > -1} {
                        # this is a hal file search ordered loop
                        set thisininame [lindex [split $tmpstring "\]" ] end ]
                        set lowername "[string tolower $thisininame]"
                        set thishalcommand [lindex $tmpstring 1]
                        set tmpval [expr [lindex [split \
                            [exec $HALCMD -s show param $thishalcommand] " "] 3]]
                        global axis$j-$lowername
                        set axis$j-$lowername $tmpval
                        set thislabel [label [set af$j].label-$j-$lowername \
                            -text "$thisininame" -width 20 -anchor e]
                        set thisentry [entry [set af$j].entry-$lowername \
                        -width 12 -textvariable axis$j-$lowername]
                        grid $thislabel $thisentry
                        lappend namearray($j) $lowername
                        lappend commandarray($j) $thishalcommand
                        lappend valarray($j) $tmpval
                        break
                    }
                }
            }
        }
    }

    frame $main.buttons
    button $main.buttons.ok -text [msgcat::mc "Save"] -default active \
        -command {changeIt save } -state disabled
    button $main.buttons.apply -text [msgcat::mc "Apply"] \
        -command {changeIt apply}
    button $main.buttons.revert -text [msgcat::mc "Revert"] \
        -command {changeIt revert} -state disabled
    button $main.buttons.cancel -text [msgcat::mc "Quit"] \
        -command {changeIt quit}
#    pack $main.buttons.ok $main.buttons.apply $main.buttons.revert \
        $main.buttons.cancel -side left -fill x -expand 1
    # grid the top display to keep stuff in place
    grid rowconfigure $main 1 -weight 1
#    remove the bottom tuning buttons for now.
#    grid configure $main.buttons -row 2 -sticky ew -ipadx 20

}

proc selectAxis {which} {
    global axisentry
    set axisentry $which
}

proc changeIt {how } {
    global axisentry sectionarray namearray commandarray valarray HALCMD
    global numaxes main oldvalarray initext
    switch -- $how {
        save {
            for {set i 0} {$i<$numaxes} {incr i} {
                set varnames [lindex [array get namearray $i] end]
                set upvarnames [string toupper $varnames]
                set varcommands [lindex [array get commandarray $i] end]
                set maxvarnum [llength $varnames]
                set sectname "AXIS_$i"
                if {$i == [expr $numaxes-1]} {
                    set endsect EMCIO
                } else {
                    set endsect AXIS_[expr $i+1]
                }
                set sectnum "[set sectionarray($sectname)]"
                set nextsectnum "[set sectionarray($endsect)]"
                $initext configure -state normal
                for {set ind $sectnum} {$ind < $nextsectnum} {incr ind} {
                    switch -- [$initext get $ind.0] {
                        "#" {}
                        default {
                            set tmpstr [$initext get $ind.0 $ind.end]
                            set tmpvar [lindex $tmpstr 0]
                            set tmpindx [lsearch $upvarnames $tmpvar]
                            if {$tmpindx != -1} {
                                set cmd [lindex $varcommands $tmpindx]
                                $initext mark set insert $ind.0
                                set newval [expr [lindex [split \
                                    [exec $HALCMD -s show param $cmd] " "] 3]]
                                set tmptest [string first "e" $newval]
                                if {[string first "e" $newval] > 1} {
                                    set newval [format %f $newval]
                                }
                                # keep everything leading up to the var value, 
                                # replace the value, and keep everything after the value
                                regsub {(^.*=[ \t]*)[^ \t]*(.*)} $tmpstr "\\1$newval\\2" newvar
                                $initext delete insert "insert lineend"
                                $initext insert insert $newvar
                            }
                        }
                    }
                }
                $initext configure -state disabled
            }
            saveFile
        }
        apply {
            $main.buttons.ok configure -state normal
            $main.buttons.revert configure -state normal
            set varnames [lindex [array get namearray $axisentry] end]
            set varcommands [lindex [array get commandarray $axisentry] end]
            set maxvarnum [llength $varnames]
            for {set listnum 0} {$listnum < $maxvarnum} {incr listnum} {
                set var "axis$axisentry-[lindex $varnames $listnum]"
                global $var
                set tmpval [set $var]
                set tmpcmd [lindex $varcommands $listnum]
                # get list of old values before changeIt apply changes them
                set tmpold [expr [lindex [split \
                    [exec $HALCMD -s show param $tmpcmd] " "] 3]]
                lappend oldvalarray($axisentry) $tmpold
                set thisret [exec $HALCMD setp $tmpcmd $tmpval]
            }
        }
        revert {
            set varnames [lindex [array get namearray $axisentry] end]
            set varcommands [lindex [array get commandarray $axisentry] end]
            set maxvarnum [llength $varnames]
            set oldvarvals [lindex [array get oldvalarray $axisentry] end]
            for {set listnum 0} {$listnum < $maxvarnum} {incr listnum} {
                set tmpval [lindex $oldvarvals $listnum]
                set tmpcmd [lindex $varcommands $listnum]
                set thisret [exec $HALCMD setp $tmpcmd $tmpval]
                # update the display
                set var axis$axisentry-[lindex $varnames $listnum]
                global $var
                set $var $tmpval
            }
            $main.buttons.revert configure -state disabled
        }
        quit {
            # build a check for changed values here and ask
            for {set j 0} {$j < $numaxes} {incr j} {
                set oldvals [lindex [array get valarray $j] 1]
                set cmds [lindex [array get commandarray $j] 1]
                set k 0
                foreach cmd $cmds {
                    set tmpval [expr [lindex [split \
                        [exec $HALCMD -s show param $cmd] " "] 3]]
                    set oldval [lindex $oldvals $k]
                    if {$tmpval != $oldval} {
                        set answer [tk_messageBox \
                            -message [msgcat::mc "The HAL parameter \n \
                            %s \n has changed. \n Really quit?" $cmd] \
                            -type yesno -icon question] 
                        switch -- $answer { \
                                yes exit
                                no {return}
                        }
                    
                    }
                    incr k
                }
            }
            destroy .
        }
        default {}
    }
}

proc saveFile {} {
    global initext thisinifile
    set name $thisinifile
    catch {file copy -force $name $name.bak}
    if {[catch {open $name w} fileout]} {
        puts stdout [msgcat::mc "can't save %s" $name]
        return
    }
    puts $fileout [$initext get 1.0 end]
    catch {close $fileout}
}


# showmode handles the tab selection of mode
proc showMode {mode} {
    global workmode
    set workmode $mode
    if {$mode=="watchhal"} {
        watchLoop
    }
}

# all clicks on tree node names go into workMode
# oldvar keeps the last HAL variable for refresh
proc workMode {which} {
    global workmode oldvar thisvar newmodvar
    set thisvar $which
    switch -- $workmode {
        showhal {
            showHAL $which
        }
        watchhal {
            watchHAL $which
        }
        modifyhal {
            set newmodvar 0
            setModifyVar $which
        }
        tunehal {
            tuneHAL $which
        }
        default {
            swapDisplay display showhal
            displayThis [msgcat::mc "Mode went way wrong."]
        }
    }
    set oldvar $which
}

# process uses it's own halcmd show so that displayed
# info looks like what is in the Hal_Introduction.pdf
proc showHAL {which} {
    global disp HALCMD
    if {![info exists disp]} {return}
    if {$which == "zzz"} {
        displayThis [msgcat::mc "Select a node to show."]
        return
    }
    set thisnode $which
    set thislist [split $which "+"]
    set searchbase [lindex $thislist 0]
    set searchstring [lindex $thislist 1]
    set thisret [exec $HALCMD show $searchbase $searchstring]
    displayThis $thisret
}

proc showEx {what} {
    global showtext
    set str [exHAL $what]
    $showtext delete 1.0 end
    $showtext insert end $str
    refreshHAL
}

set watchlist ""
set watchstring ""
proc watchHAL {which} {
    global watchlist watchstring watching cisp
    if {$which == "zzz"} {
        $cisp create text 40 [expr 1 * 20 + 12] -anchor w -tag firstmessage\
            -text [msgcat::mc "<-- Select a Leaf.  Click on its name."]
        set watchlist ""
        set watchstring ""
        return
    } else {
        $cisp delete firstmessage
    }
    # return if variable is already used.
    if {[lsearch $watchlist $which] != -1} {
        return
    }
    lappend watchlist $which
    set i [llength $watchlist]
    set label [lindex [split $which +] end]
    set tmplist [split $which +]
    set vartype [lindex $tmplist 0]
    set varname [lindex $tmplist end]
    set ret [exHAL "show $vartype $varname"]
    if {[lsearch $ret "bit"] != -1 } {
        $cisp create oval 20 [expr $i * 20 + 5] 35 [expr $i * 20 + 20] \
            -fill firebrick4 -tag oval$i
        $cisp create text 80 [expr $i * 20 + 12] -text $label \
            -anchor w -tag $label
    } else {
        # other gets a text display for value
        $cisp create text 10 [expr $i * 20 + 12] -text "xxxx" \
            -anchor w -tag text$i
        $cisp create text 80 [expr $i * 20 + 12] -text $label \
            -anchor w -tag $label
        }
    set tmplist [split $which +]
    set vartype [lindex $tmplist 0]
    set varname [lindex $tmplist end]
    lappend watchstring "$i $vartype $varname "
    if {$watching == 0} {watchLoop} 
}

# watchHAL prepares a string of {i HALtype name} sets
# watchLoop submits these to halcmd and sets canvas
# color or value based on reply
set watching 0
proc watchLoop {} {
    global cisp watchstring watching workmode
    set watching 1
    set which $watchstring
    foreach var $which {
        scan $var {%i %s %s} cnum vartype varname
        if {$vartype == "sig" } {
            set ret [lindex [exHAL "show $vartype $varname"] 1]
        } else {
            set ret [lindex [exHAL "show $vartype $varname"] 3]
        }
        if {$ret == "TRUE"} {
            $cisp itemconfigure oval$cnum -fill yellow
        } elseif {$ret == "FALSE"} {
            $cisp itemconfigure oval$cnum -fill firebrick4
        } else {
            set value [expr $ret]
            $cisp itemconfigure text$cnum -text $value
        }
    }
    if {$workmode == "watchhal"} {
        after 1000 watchLoop
    } else {
        set watching 0
    }
}

proc watchReset {del} {
    global watchlist cisp
    $cisp delete all
    switch -- $del {
        all {
            watchHAL zzz
            return
        }
        default {
            set place [lsearch $watchlist $del]
            if {$place != -1 } {
            set watchlist [lreplace $watchlist $place]
                foreach var $watchlist {
                    watchHAL $var
                }
            } else {            
                watchHAL zzz
            }
        }
    }
}

# modHAL gets the return from a halcmd and displays it.
proc modHAL {command} {
    global modtext
    set str [exHAL "$command"]
    $modtext delete 1.0 end
    $modtext insert end $str
    # this refresh takes a while on slow boxes.  Might think about 
    # modifying the tree code rather than erase and rebuild.
    refreshHAL
}

proc setModifyVar {which} {
    global modtext treenodes modifyhal modlist modtypes
    # test to see if which is a leaf or node
    set isleaf [lsearch $treenodes $which]
    if {$isleaf == -1} {
        foreach w $modlist {
            $w configure -bg white
        }
        set tmp [split $which +]
        scan $tmp { %s %s } haltype varname
        # setup mode of entry widgets in modifyhal so they match
        # haltype above and so a click on available widget
        # inserts the varname above
        switch -- $haltype {
            pin {
                set str [msgcat::mc "Click a highlighted entry where %s should go." $which]
                set tmp $modtypes(pin)
                foreach widget $tmp {
                [subst $widget] configure -bg lightgreen
                }
            }
            param {
                set str [msgcat::mc "Nothing to be done for parameters here. Try the tuning page"]
            }
            sig {
                set str [msgcat::mc "Click a highlighted entry where %s should go." $which]
                set tmp [lindex [array get modtypes sig] 1]
                foreach widget $tmp {
                    [subst $widget] configure -bg lightgreen
                }
            }
            comp {
                set str [msgcat::mc "Click a highlighted entry where %s should go." $which]
                set tmp [lindex [array get modtypes comp] 1]
                foreach widget $tmp {
                    [subst $widget] configure -bg lightgreen
                }
            }
            funct {
                set str [msgcat::mc "Click a highlighted entry where %s should go." $which]
                set tmp [lindex [array get modtypes funct] 1]
                foreach widget $tmp {
                    [subst $widget] configure -bg lightgreen
                }
            }
            thread {
                set str [msgcat::mc "Click a highlighted entry where %s should go." $which]
                set tmp [lindex [array get modtypes thread] 1]
                foreach widget $tmp {
                    [subst $widget] configure -bg lightgreen
                }
            }
        }            
    } else {
        set str [msgcat::mc "%s is not a leaf, try again" $which]
    }
    $modtext delete 1.0 end
    $modtext insert end $str
}

proc copyVar {var} {
    global thisvar newmodvar
    if {$newmodvar == 0 } {
    #    puts $var
        set tmpvar [lindex [split $thisvar +] end]
        $var insert 0 $tmpvar
        set newmodvar 1
    }
}


# proc switches the insert and removal of upper right text
# This also removes any modify array variables
proc displayThis {str} {
    global disp
    $disp configure -state normal 
    $disp delete 1.0 end
    $disp insert end $str
    $disp configure -state disabled
}


#----------start up the displays----------
makeShow
makeWatch
makeModify
# makeTune
refreshHAL

#----------save config----------
#
# save will assume that restarting is from a comp and netlist
# we need to build these files and copy .ini for the new
proc saveHAL {which} {
    global HALCMD
    switch -- $which {
        save {
            displayThis [exec $HALCMD save "comp"]
        }
        saveas {}
        saveandexit {
            exit {destroy . }
        }
    }
}

#----------Help processes----------
#
proc showHelp {which} {
    global helpabout helpmain helpcomponent helppin helpparameter
    global helpsignal helpfunction helpthread
    switch -- $which {
        about {displayThis  $helpabout}
        main {displayThis  "find help file"}
        default {I'm lost here in help land}
    }
}

# Help includes sections for each of these
# Components Pins Parameters Signals Functions Threads

set helpabout {
     Copyright Raymond E Henry. 2006
     License: GPL Version 2

     Halconfig is an EMC2 configuration tool.  It should be started from the emc2 directory and will require that you have started an instance of emc2 or work up a new configuration starting with a demo rt script.

     This script is not for the faint hearted and carries no warranty or liability for its use to the extent allowed by law.
}

makeTune
$top raise ps
