include <params.scad>
use <hardware.scad>

// Electronics carrier tray: Pico on short bosses, universal board on tall
// corner posts above it. The whole tray screws down into the body floor.
// Footprint centered at origin, long axis (Pico length / uboard long side)
// along Y — matching how the body orients the Pico.
module tray() {
  difference() {
    union() {
    // floor plate
    translate([0, 0, tray_t/2])
      cube([tray_fw, tray_fl, tray_t], center = true);

    // Pico short bosses (reuse hardware module), long axis along Y
    translate([0, 0, tray_t])
      rotate([0, 0, 90]) pico_w_mounts();

    // universal-board support posts at the datasheet corner pitch. The board
    // corners rest on these flat tops (held by solder to the Pico pins). Each
    // post doubles as the tray->body anchor: the screw comes up from the body
    // underside and self-taps into the post (pilot cut below), so the same 4
    // posts fix both the board and the body — no separate bosses.
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2, sy * uboard_mount_span_l/2, tray_t])
        cylinder(d = tray_post_d, h = tray_post_h);
    }

    // orientation marker: recessed arrow into the +Y (USB) end of the floor.
    // Seat the Pico with its USB connector on this side — the body's USB opening
    // is on the +Y wall.
    tray_usb_marker();

    // tray->body screw pilots, fed from BELOW up into the support posts (leave a
    // 1mm cap so the board still rests on a solid post top).
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2, sy * uboard_mount_span_l/2, -0.1])
        cylinder(d = tray_screw_pilot, h = tray_t + tray_post_h - 1 + 0.1);
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
