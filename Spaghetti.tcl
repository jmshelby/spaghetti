package require Tclx

# Constants
set pi 3.1415926535897932384626433832795
set threeSixty [expr $pi * 2]

set info(init_coord) {400 400}
set info(units) 5
set info(line,width) 2
set info(line,rotate_incr) [expr $pi / 2 ]

# Graphics Engine Configs
set state(line,dir_angle:old) [expr $pi / 2]
set state(line,dir_angle:cur) [expr $pi / 2]
set state(line,coord:cen) $info(init_coord)
set state(line,coord:cur) [list [lindex $info(init_coord) 0] [expr [lindex $info(init_coord) 1] - $info(units)]]

proc get_rotated_point {point_coord origin_coord theta_incr} {

	lassign $point_coord  cur_x cur_y
	lassign $origin_coord cen_x cen_y

	# Subtract back to origin
	set cur_x [expr $cur_x - $cen_x]
	set cur_y [expr $cur_y - $cen_y]

	# Calculate new sprite end-points
	set new_x [expr cos($theta_incr) * $cur_x - sin($theta_incr) * $cur_y]
	set new_y [expr sin($theta_incr) * $cur_x + cos($theta_incr) * $cur_y]

	# Add back to current pos
	set new_x [expr $new_x + $cen_x]
	set new_y [expr $new_y + $cen_y]

	set new_point_coord [list $new_x $new_y]

	return $new_point_coord
}


proc rotate_line {rotate_dir} {
	global state info

	switch $rotate_dir {
		cc {set theta_incr [expr -1 * $info(line,rotate_incr)]}
		cw {set theta_incr $info(line,rotate_incr)}
	}

	set cen_coord $state(line,coord:cen)
	set cur_coord $state(line,coord:cur)

	set new_coord [get_rotated_point $cur_coord $cen_coord $theta_incr]
	
	lassign $new_coord newX newY

	set new_full_coords [concat $cen_coord $new_coord]

	.c coords guide_line $new_full_coords

	# Update current guide point coordinates
	set state(line,coord:cur) $new_coord

	# Update current direction angle
	set state(line,dir_angle:old) $state(line,dir_angle:cur)
	set state(line,dir_angle:cur) [expr $state(line,dir_angle:cur) + $theta_incr]

}

proc addNewPoint { {restrict 1} } {
	global state info

	set theta $state(line,dir_angle:cur)

	# Calulate the new coord increments for x and y (going in a certain direction, in angle measurement)
	set x_incr [expr cos($theta) * $info(units)]
	set y_incr [expr sin($theta) * $info(units)]

	lassign $state(line,coord:cen) cen_x cen_y
	lassign $state(line,coord:cur) cur_x cur_y

	# Make sure we actually can go forward
	if {$restrict && ![canDrawLine [list $cen_x $cen_y $cur_x $cur_y]]} {
		return 0
	}

	set newPoint_x [expr $cur_x + $x_incr]
	set newPoint_y [expr $cur_y + $y_incr]

	set newCoord [list $cur_x $cur_y]
	set newGuideCoords [list $cur_x $cur_y $newPoint_x $newPoint_y]

	# Update current state coords
	set state(line,coord:cen) $state(line,coord:cur)
	set state(line,coord:cur) [list $newPoint_x $newPoint_y]

	# Update Canvas
	.c insert line end $newCoord
	.c coords guide_line $newGuideCoords

	return 1
}

proc isOutOfBounds {checkPoint} {
	lassign $checkPoint left top

	if {$top < 0 || $left < 0} {
		return 1
	}

	if {$top > [winfo height .c]} {
		return 1
	}

	if {$left > [winfo width .c]} {
		return 1
	}

	return 0
}

proc canDrawLine {lineCoords} {
	global info

	# Get the shorter line to check for interections
	set shorterLine [getShortendGuideLine $lineCoords]
	lassign $shorterLine x1 y1 x2 y2

	# First make sure we're not out going of bounds
	if {[isOutOfBounds [list $x2 $y2]]} {
		return 0
	}

	set foundItems [.c find overlapping $x1 $y1 $x2 $y2]

	foreach item $foundItems {
		set tags [.c gettags $item]
		if {[lcontain $tags line]} {
			return 0
		}
	}

	return 1
}

proc getShortendGuideLine {lineCoords} {

	lassign $lineCoords x1 y1 x2 y2

	# Need to move up line, a little bit so we're not already intersecting ourself
	set totalDistance [expr sqrt( pow($x2-$x1,2) + pow($y2-$y1,2) ) ]
	#set scaled [expr 2 / $totalDistance]
	set scaled 0.25

	set xStart [expr (1 - $scaled) * $x1 + $scaled * $x2]
	set yStart [expr (1 - $scaled) * $y1 + $scaled * $y2]

	return [list $xStart $yStart $x2 $y2]
}

proc startNewLine {} {
	global info state
	set init_coords [concat $info(init_coord) $info(init_coord)]
	set init_guide_coords [concat $info(init_coord) $state(line,coord:cur)]
	.c create line $init_coords -tag line -fill green -width $info(line,width)
	.c create line $init_guide_coords -tag guide_line -fill red -width $info(line,width)
}

proc relocateFromBeingStuck {} {
}

proc automaticMove {} {
	global info threeSixty

	set spin [expr int(50 * rand())]
	if {$spin == 5} {
		puts "gonna go erradic..."
		rotate_line cc
		set spin [expr int(10 * rand())]
		for {set i 0} {$i<=$spin} {incr i} {
			# TODO - call self recursively maybe??
			addNewPoint
		}
	}

	# Go clock-wise 2 times
	rotate_line cw
	rotate_line cw

	# Figure out how many increments each rotation counts toward
	set increments [expr $threeSixty / $info(line,rotate_incr)]
	set tries 0

	while {$tries < $increments} {
		set moved [addNewPoint]
		if (!$moved) {
			rotate_line cc
			incr tries
		} else {
			break;
		}
	}

	if {$moved} {
		return 1
	} else {
		puts "stuck"
		#relocateFromBeingStuck
		return 0
	}
}

proc buttonDown {} {
	global state info

	lassign $state(line,coord:cen) cen_x cen_y
	lassign $state(line,coord:cur) cur_x cur_y

	set longLine [list $cen_x $cen_y $cur_x $cur_y]
	set shortLine [getShortendGuideLine [list $cen_x $cen_y $cur_x $cur_y]]

	.c create rectangle $shortLine -tag reference_line -fill blue -outline blue -width 0.01
}

proc buttonUp {} {
	.c delete reference_line
}


proc autoPilot {} {
	set notStuck 1
	while {$notStuck} {
		after 1
		set notStuck [automaticMove]
		update
	}
}



bind . <ButtonPress-1> {buttonDown}
bind . <ButtonRelease-1> {buttonUp}
bind . <KeyPress-Left>  {rotate_line cc}
bind . <KeyPress-Right> {rotate_line cw}
bind . <KeyPress-Up>	{addNewPoint 0}

bind . <KeyPress-Down>  {autoPilot}



canvas .c -background black
pack .c -expand yes -fill both

startNewLine



