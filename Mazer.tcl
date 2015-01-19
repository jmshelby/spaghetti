package require Tclx

# Constants
set refresh 1
set pi 3.141592654
#set pi 3.1415926535897932384626433832795

set info(init_coord) {100 100}
set info(units) 10
set info(line,width) 1
set info(line,rotate_incr) [expr $pi / 2 ]
set bufferList ""
set directionList ""

# Graphics Engine Configs
set state(line,dir_angle:old) [expr $pi / 2]
set state(line,dir_angle:cur) [expr $pi / 2]
set state(line,coord:cen) $info(init_coord)
set state(line,coord:cur) [list [lindex $info(init_coord) 0] [expr [lindex $info(init_coord) 1] - $info(units)]]
set state(line,dir_vec) {0 $info(units)}

canvas .c -background black
pack .c -expand yes -fill both

set init_coords [concat $info(init_coord) $info(init_coord)]
set init_guide_coords [concat $info(init_coord) $state(line,coord:cur)]
.c create line $init_coords -tag line -fill green -width $info(line,width)
.c create line $init_guide_coords -tag guide_line -fill red -width $info(line,width)

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

	puts "theta_incr= $theta_incr"
	puts "cur_coord= $cur_coord"
	puts "cen_coord= $cen_coord"
	puts "new_coord= $new_coord"
	puts "new_full_coords= $new_full_coords"
	.c coords guide_line $new_full_coords

#canDrawLine $new_full_coords

	# Update current guide point coordinates
	set state(line,coord:cur) $new_coord

	# Update current direction angle
	set state(line,dir_angle:old) $state(line,dir_angle:cur)
	set state(line,dir_angle:cur) [expr $state(line,dir_angle:cur) + $theta_incr]

}

proc try_add_new_point {} {
	global state info

	set theta $state(line,dir_angle:cur)

	# Calulate the new coord increments for x and y (going in a certain direction, in angle measurement)
	set x_incr [expr cos($theta) * $info(units)]
	set y_incr [expr sin($theta) * $info(units)]

	lassign $state(line,coord:cen) cen_x cen_y
	lassign $state(line,coord:cur) cur_x cur_y

	# Make sure we actually can go forward
	if {![canDrawLine [list $cen_x $cen_y $cur_x $cur_y]]} {
		puts "cant draw line"
		return 0
	}

	set newPoint_x [expr $cur_x + $x_incr]
	set newPoint_y [expr $cur_y + $y_incr]

	set newCoord [list $cur_x $cur_y]
	set newGuideCoords [list $cur_x $cur_y $newPoint_x $newPoint_y]

	.c insert line end $newCoord
	.c coords guide_line $newGuideCoords

	set state(line,coord:cen) $state(line,coord:cur)
	set state(line,coord:cur) [list $newPoint_x $newPoint_y]

	return 1
}

proc canDrawLine {lineCoords} {
	global info

	set shorterLine [getShortendGuideLine $lineCoords]

	lassign $shorterLine x1 y1 x2 y2

	set foundItems [.c find overlapping $x1 $y1 $x2 $y2]

	foreach item $foundItems {
		set tags [.c gettags $item]
		puts "-> found intersecting tags: $tags"
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
	set scaled 0.2

	set xStart [expr (1 - $scaled) * $x1 + $scaled * $x2]
	set yStart [expr (1 - $scaled) * $y1 + $scaled * $y2]

	return [list $xStart $yStart $x2 $y2]
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


proc automaticMove {} {
}


bind . <ButtonPress-1> {buttonDown}
bind . <ButtonRelease-1> {buttonUp}
bind . <KeyPress-Left>  {rotate_line cc}
bind . <KeyPress-Right> {rotate_line cw}
bind . <KeyPress-Up>	{try_add_new_point}

bind . <KeyPress-Down>  {automaticMove}












