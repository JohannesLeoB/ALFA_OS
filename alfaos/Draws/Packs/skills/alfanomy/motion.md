# Motion

Parts that open are units: drawers, pull-outs, doors, flaps. Leave units out when nothing opens.

- Fronts versus body. A front is a thin part (18 mm thick, role FRONT) in front of the carcass, with 2 mm gaps to its neighbours. The body is what moves with the front, for example a drawer box. Every id in fronts and body is an existing part; a part belongs to at most one unit.
- Drawer and pull-out slide out of the front along -y by the inner depth of the carcass, for example dy -450 for a carcass 560 mm deep, dx and dz 0.
- Door: hinge with axis z. px, py, pz is a point on the hinge edge of the front, in the front plane. The opening angle is 90 to 110 degrees. For a front facing -y, a door hinged on its low-x edge uses a negative angle, a door hinged on its high-x edge a positive one.
- Flap: hinge with axis x. A flap hinged on its top edge uses a negative angle, one hinged on its bottom edge a positive one.
- One unit per leaf when doors hang together in one opening.
- Show motion with set_pose: 0 is closed, 1 is fully open, 0.5 shows the middle. Show at least one unit open in the preview when the object has units.
- The readout comes from the model: unit width, fronts, travel now and at most. Quote those numbers, do not calculate them.
