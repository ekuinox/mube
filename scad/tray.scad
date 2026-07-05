include <params.scad>
use <hardware.scad>

// Electronics carrier tray: Pico on short bosses, universal board on tall
// corner posts above it. The whole tray screws down into the body floor.
// Footprint centered at origin, long axis (Pico length / uboard long side)
// along Y — matching how the body orients the Pico.
module tray() {
  difference() {
    union() {
    // floor plate — shifted by the board offset so it stays under the posts,
    // while the Pico bosses and everything else keep their absolute positions.
    translate([uboard_mount_off_x, uboard_mount_off_y, tray_t/2])
      cube([tray_fw, tray_fl, tray_t], center = true);

    // Pico short bosses (reuse hardware module), long axis along Y
    translate([0, 0, tray_t])
      rotate([0, 0, 90]) pico_w_mounts();

    // universal-board support posts at the (measured-offset) corner pitch. The
    // board corners rest on the flat tops. Each post is hollow and acts as the
    // M2 spacer for a single screw that clamps body + tray + board together (see
    // the through-hole cut below); an M2 nut on top of the board caps it.
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2 + uboard_mount_off_x,
                 sy * uboard_mount_span_l/2 + uboard_mount_off_y, tray_t])
        cylinder(d = tray_post_d, h = tray_post_h);
    }

    // orientation marker: recessed arrow into the +Y (USB) end of the floor.
    // Seat the Pico with its USB connector on this side — the body's USB opening
    // is on the +Y wall.
    tray_usb_marker();

    // through clearance for the clamp screw: it passes from the body underside
    // up the hollow post and through the board hole to the nut on top.
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2 + uboard_mount_off_x,
                 sy * uboard_mount_span_l/2 + uboard_mount_off_y, -0.1])
        cylinder(d = tray_screw_clear, h = tray_t + tray_post_h + 0.2);
  }
}

// Recessed arrow on the floor top pointing +Y (the USB side), roughly Pico-boss
// sized. Sits in the clear band beyond the Pico.
module tray_usb_marker() {
  depth = 0.6;
  translate([0, 30, tray_t - depth])
    linear_extrude(height = depth + 0.1)
      polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
