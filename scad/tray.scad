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

    // universal-board support posts at the datasheet corner pitch;
    // M2 self-taps into the top of each post through the board's φ3.2 hole
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2, sy * uboard_mount_span_l/2, tray_t])
        difference() {
          cylinder(d = tray_post_d, h = tray_post_h);
          translate([0, 0, tray_post_h - 6])
            cylinder(d = tray_screw_pilot, h = 6 + 0.1);
        }

    // tray floor pass-through for M2 shank; the body boss self-taps
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * tray_screw_span_w/2, sy * tray_screw_span_l/2, 0])
        difference() {
          cylinder(d = tray_post_d, h = tray_t);
          translate([0, 0, -0.1])
            cylinder(d = tray_screw_clear, h = tray_t + 0.2);
        }
    }

    // orientation marker: recess "USB" + an arrow into the +Y (USB) end of the
    // floor. Seat the Pico with its USB connector on this side — the body's USB
    // opening is on the +Y wall.
    tray_usb_marker();
  }
}

// Recessed "USB" text and a +Y arrow on the floor top, clear of the Pico
// footprint, screw bosses (±tray_screw_span_w/2) and posts (±uboard_mount_span_w/2).
module tray_usb_marker() {
  depth = 0.6;
  translate([0, 0, tray_t - depth]) {
    translate([0, 29, 0])
      linear_extrude(height = depth + 0.1)
        text("USB", size = 5, halign = "center", valign = "center");
    translate([0, 31.5, 0])
      linear_extrude(height = depth + 0.1)
        polygon(points = [[-3, 0], [3, 0], [0, 4]]);
  }
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
