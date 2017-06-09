/*
Sylvan Zheng
CPSC 431 Final Project
"As Space Expanded, The Universe Cooled"
creating music from the motions of stars and planets
Can control parameters with Kinectv2 motions or with mouse and keyboard
using https://github.com/microcosm/KinectV2-OSC
* Click and drag to create stars (or bring hands together and open them)
* Click to create planets (or close and open left hand)
* Use arrow keys (or wave your right hand) to exert a force on all bodies
*
* Ideas for further work:
*   Spatialization - either >2 channel audio or binaural
*   Spatialization in a visual sense? only in IMAX or VR I feel
*    Is this like a concert/performance? or for individuals?
*    Kinect makes it seem like it should be more of a performance
*   Associate octave, speed with creation gesture somehow. These are the most salient factors anyway
*   Multiplayer?
*/

(

var gforce = 11;  // Gravitational constant, increase to increase force of attraction
var scale = 12;  // size of the universe

var width = Window.screenBounds.width * scale;
var height = Window.screenBounds.height * scale;
var depth = 768 * scale;
var maxDist = RealVector3D[width/2, height/2, depth/2].norm;

var friction = 50000000; // Larger means less friction

// Musical information
var tonics = [[1, [\ionian, \mixolydian]]];
var dominants = [[5, [\ionian, \mixolydian]], [7, [\ionian, \mixolydian]]];
var predominants = [[2, [\ionian, \aeolian]], [4, [\ionian]]];
var tsubs = [[3, [\ionian]], [6, [\ionian]]];
var chords = [tonics, dominants, predominants, tsubs];
var tones = [1,2,3,5,6,7];
var largestCell;

var gestureD = (
	HandLeft: (
		pos: RingBuffer2.new(10),
		counter: 0,
		state: \open,
		counter2: 0,
		cloud: nil,
	),
	HandRight: (
		pos: RingBuffer2.new(10),
		matchCounter: 0,
		state: \open,
		matchOrigin: 0,
		cell: 0,
		cloud: nil,
		counter: 0;
	),
);

var newCloud = { |vec, type|
	(
		type: type,
		pos: vec,
		counter: 0,
		size: 100,
	);
};

var oscFunc = { |msg, time, addr|
	// Right Hand Gestures
	// Open hand and wave it around to exert a force on all the planets
	if (msg[0].matchOSCAddressPattern('/bodies/*/hands/Right'), {
		var dict = gestureD[\HandRight];
		if (dict[\state] == \open, {
			var msg1 = \open;
			if (msg[1] == 'Open', {
				dict[\counter] = dict[\counter] + 1;
				if (dict[\counter] == 5, {
					dict[\cloud] = newCloud.(dict[\pos].lastWritten, \Lasso);
					dict[\state] = \lasso;
					dict[\counter] = 0;
				});
			}, { dict[\counter] = 0; } );
		});
		if (dict[\state] == \lasso, {
			var ms1g = \lasso;
			dict[\cloud][\pos] = dict[\pos].lastWritten;

			if (msg[1] != 'Open', {
				dict[\counter] = dict[\counter] + 1;
				if (dict[\counter] == 5, {
					dict[\state] = \open;
					dict[\cloud] = nil;
					dict[\counter] = 0;

				});
			}, {
				var delta = (translateKinectCoords.(dict[\pos].lastWritten) - translateKinectCoords.(dict[\pos].lastWritten(2)));
				dict[\counter] = 0;
				cells.do { |cell|
					cell[\vel] = delta/4/(cell[\size] ** 0.3) + cell[\vel];
				};
			});
		});
	});
	// Left Hand Gestures
	// Close hand and open it to give birth to a planet
	if (msg[0].matchOSCAddressPattern('/bodies/*/hands/Left'), {
		var dict = gestureD[\HandLeft];
		if (dict[\state] == \open, {
			if (msg[1] == 'Closed', {
				dict[\counter] = dict[\counter] + 1;
				if (dict[\counter] == 15, {
					dict[\cloud] = newCloud.(dict[\pos].lastWritten, \closed);
					dict[\state] = \closed;
					dict[\counter] = 0;
				});
			}, { dict[\counter] = 0; });
		});
		if (dict[\state] == \closed, {
			dict[\cloud][\pos] = dict[\pos].lastWritten;
			dict[\counter2] = dict[\counter2] + 1;
			if (dict[\counter2] == 60, {
				dict[\state] = \open;
				dict[\counter] = 0;
				dict[\counter2] = 0;
				dict[\cloud] = nil;
			});
			if (msg[1] == 'Open', {
				dict[\counter] = dict[\counter] + 1;
				if (dict[\counter] == 3, {
					dict[\state] = \open;
					dict[\counter] = 0;
					dict[\counter2] = 0;
					dict[\cloud] = nil;
					cells = cells.add(createCell.(translateKinectCoords.(dict[\pos].lastWritten)));
				});
			}, { dict[\counter] = 0; });
		});
	});
	// Left Hand Gestures
	if (msg[0].matchOSCAddressPattern('/bodies/*/joints/HandTipLeft'), {
		var dict = gestureD[\HandLeft];
		var newpos = RealVector3D[msg[1],msg[2],msg[3]];
		dict[\pos].overwrite(newpos);
	});
	// Right Hand Gestures
	// If touching left hand, give birth to a star
	if (msg[0].matchOSCAddressPattern('/bodies/*/joints/HandTipRight'), {
		var threshold = 0.09;
		var touch_thresh_time = 5;
		var expand_start_thresh = 0.15;
		var release_dist_thresh = 0.01;
		var release_thresh_time = 5;
		var dict = gestureD[\HandRight];
		var leftdict = gestureD[\HandLeft];
		dict[\pos].overwrite(RealVector3D[msg[1],msg[2],msg[3]]);

		if (dict[\state] == \open, {
			if (dict[\pos].lastWritten.dist(leftdict[\pos].lastWritten) < threshold, {
				dict[\matchCounter] = dict[\matchCounter] + 1;
				if (dict[\matchCounter] == touch_thresh_time, {
					dict[\state] = \expand_wait;
					leftdict[\state] = \expand_wait;
					leftdict[\counter] = 0;
					leftdict[\counter2] = 0;
					dict[\matchOrigin] = dict[\pos].lastWritten;
					dict[\matchCounter] = 0;
					dict[\cloud] = newCloud.(dict[\pos].lastWritten + leftdict[\pos].lastWritten / 2, \expand);
					dict[\cloud][\size] = 10;
				});
			}, { dict[\matchCounter] = 0; });
		});
		if (dict[\state] == \expand_wait, {
			var dist = dict[\pos].lastWritten.dist(leftdict[\pos].lastWritten);
			dict[\matchCounter] = dict[\matchCounter] + 1;
			dict[\cloud][\pos] = dict[\pos].lastWritten + leftdict[\pos].lastWritten / 2;
			dict[\cloud][\size] = dist * 100 + 20;
			if  (dist > expand_start_thresh, {
				if (dict[\matchCounter] > 45, {
					dict[\state] = \open;
					leftdict[\state] = \open;
					dict[\matchCounter] = 0;
					dict[\cloud] = nil;
				}, {
					dict[\state] = \expanding;
					dict[\matchCounter] = 0;
					//dict[\cell][\size] = dist * 400000;
				});
			});
		});
		if (dict[\state] == \expanding, {
			var dist = dict[\pos].lastWritten.dist(leftdict[\pos].lastWritten);
			var delta = dict[\pos].lastWritten.dist(dict[\pos].lastWritten(2));
			dict[\cloud][\size] = dist * 100 + 20;


			if (delta < release_dist_thresh, {
				dict[\matchCounter] = dict[\matchCounter] + 1;
				if (dict[\matchCounter] == release_thresh_time, {
					dict[\cloud] = nil;
					dict[\cell] = createCell.(translateKinectCoords.(dict[\pos].lastWritten + leftdict[\pos].lastWritten / 2), dist * 400000);
					cells = cells.add(dict[\cell]);
					dict[\state] = \open;
					leftdict[\state] = \open;
					dict[\matchCounter] = 0;
					if (dict[\cell][\size] > largestCell[\size], {
						largestCell = dict[\cell];
					});
				});
			}, { dict[\matchCounter] = 0; });
		});
	});
};

var cells = [];

// Translate kinect coordinates to universe coordinates
var translateKinectCoords = { |pos|
	pos = pos + RealVector3D[1,1,0] * RealVector3D[width/2, height/2, depth/3];
	pos[1] = pos.y.linlin(0,height, height, 0);
};

// Translate 3D coordinates to 2d space
var translateCoords = { |vec|
	var xcoord = vec.x * 2 / width - 1;
	var ycoord = vec.y * 2 / height - 1;
	var zdep = vec.z / depth + 1;
	xcoord = xcoord / zdep * width / 2 + (width/2) ;
	ycoord = ycoord / zdep * height/ 2 + (height/2);
	RealVector2D[xcoord, ycoord];
};

var drawCell = { |cell|
	var sqSize = cell[\size] ** 0.25 * 24;
	var sc = translateCoords.(cell[\pos]);
	sqSize = cell[\pos].z/depth * sqSize + 1;
	Pen.fillOval(Rect(sc.x - sqSize/scale, sc.y - sqSize/scale, sqSize*2/scale, sqSize*2/scale));
};

var gravity = { |cellA, cellB|
	// F = GMM/r^2
	// ma = GMM/r^2
	// a = GM/r^2 Acceleration of body A is G * mass of body B / r^2
	// Calculate normal vector
	var distance = cellA[\pos].dist(cellB[\pos]);
	var delta = (cellB[\pos] - cellA[\pos])/distance;
	// Get unit vector of force
	var distanceSq = distance ** 2;

	var accA = gforce * cellB[\size] / distanceSq;
	var accB = gforce * cellA[\size] / distanceSq;

	cellA[\vel] = delta * accA + cellA[\vel];
	cellB[\vel] = delta * accB.neg() + cellB[\vel];

};

var createCell = { |pos = nil, initsize = 0|

	var maxsize = 1000;
	var octave;
	var size = maxsize.rand + 5;
	if (initsize != 0, {
		octave =  initsize.linlin(0, 1000000, 5,3).asInteger;
	}, {
		octave = size.linlin(5, maxsize+5, 9, 4).asInteger;
	});
	size = size + initsize;

	pos = if (pos == nil, {RealVector3D[width.rand, height.rand, depth.rand]},
		{ pos; }
	);
	(
		pos: pos,
		vel: RealVector3D[20.0.xrand2(), 20.0.xrand2(), 20.0.xrand2()],
		color: Color.rand(0.5,1.0),
		size: size,
		fric: exp(size.neg()/friction),
		octave: octave,
		notecolor: tones.size().rand.asInteger,
		synth: Synth(\cell2, [amp: 0]),
	);
};

var getNotes = { |cell|
	// Given the cell that controls the chord progression, return
	// an array of notes that we are allowed to use
	//	var dist = (cell[\pos].dist([width/2, height/2,depth/2])/maxDist).clip(0,0.99);
	var vel = cell[\vel].norm.sqrt.linlin(0,10,0,0.99);
	var index = (vel*chords.size()).asInteger;
	//var mindex = (dist * modes.size()).asInteger;
	//	var mode = modes[mindex];
	//var degrees = Scale.at(mode).degrees;
	if ( a != index, {
		// Pick a chord
		var chordobj = chords[index].choose;
		var chord = chordobj[0];
		var mode = chordobj[1].choose;
		var degrees = Scale.at(mode).degrees;
		mode.postln;
		a = index;
		b = tones.collect { |tone|
			degrees[tone + chord - 2 % degrees.size()];
		}.sort;
	}, { b; });

};

// Everyone likes saw waves
SynthDef(\cell2, { |freq=440, amp=1, pan=0, ffreq=10000, lfo = 0.5, lfofreq = 1, verb=0.5, detune= 1|
	var sig, base, filter, reverb;
	base = Mix.ar([Saw.ar(freq, amp), Saw.ar(detune * freq, amp), Saw.ar(freq/2, amp)]/3);
	filter = LPF.ar(base, ffreq);
	reverb = FreeVerb.ar(filter, verb, 0.8);
	sig = HPF.ar(reverb , 60);
	Out.ar(0, Pan2.ar(sig, pan));
}).add;

a = -1;
b = -1;
c = -1;
cells = cells.add(createCell.());
cells[0][\size] = 330000;
cells[0][\pos] = RealVector3D[width/2,height/2,depth/2];
cells[0][\vel] = RealVector3D[0,0,0];
largestCell = cells[0];

thisProcess.addOSCRecvFunc(oscFunc);

w = Window("Cells", Rect((Window.screenBounds.width/2)-(width/scale/2), Window.screenBounds.height/2-(height/scale/2), width/scale, height/scale), false, false).front;

w.onClose = {
	thisProcess.removeOSCRecvFunc(oscFunc);
	cells.do { |cell|
		cell[\synth].free;
	};
};

u = UserView(w, Rect(0, 0, width, height));
u.background = Color.new(0.1, 0.1, 0.1);
u.animate = true;
u.frameRate = 24;
u.drawFunc = {

	var toRemove = [];
	var scan = false;
	var vnotes;
	var zcells;

	// Update cell movement
	cells.do { |cell|
		var distance;
		cell[\pos] = cell[\pos] + cell[\vel];
		cell[\vel] = cell[\vel] * cell[\fric];
		distance = cell[\pos].dist(RealVector3D[width/2, height/2, depth/2]);
		// Boot out cells out of bounds
		if (distance > (maxDist * 3), {
			var amp = 0.3 * exp(distance.neg/10000).postln;
			toRemove = toRemove.add(cell);
		});
	};

	toRemove.do { |cell|
		if (cell == largestCell, {
			scan = true;
		});

		cell[\synth].free;
		cells.remove(cell);
	};

	// Reassign largestCell if it was booted out
	if (scan, {
		largestCell = cells[0];
		cells.do { |cell|
			largestCell = if (cell[\size] > largestCell[\size], { cell }, { largestCell });
		};
	});

	// Gravity!
	cells.do { |cellA, i|
		cells.do { |cellB, j|
			if (i < j, {
				gravity.(cellA, cellB);
			});
		}
	};

	// Set audio parameters
	vnotes = getNotes.(largestCell);
	cells.do { |cell, i|

		var angleXY = atan(cell[\vel].y/(cell[\vel].x + 0.01)) + (pi/2)/pi;
		var angleXZ = atan(cell[\vel].z/(cell[\vel].x + 0.01)) + (pi/2)/pi;
		var angleYZ = atan(cell[\vel].z/(cell[\vel].y + 0.01)) + (pi/2)/pi;

		var index = (angleXY * cell[\notecolor]).asInteger;

		var distance = cell[\pos].dist(RealVector3D[width/2, height/2, depth/2]);
		var velocity = cell[\vel].norm;
		var center = 0.3;
		var amp = center * exp(distance.neg/10000);

		cell[\synth].set("ffreq", min(velocity * 33 + 100, 15000));
		cell[\synth].set("amp", amp);
		cell[\synth].set("freq", (cell[\octave] * 12 + vnotes[index]).midicps);
		cell[\synth].set("detune", (cell[\pos].y/height * 0.02 + 0.99));
		cell[\synth].set("pan", cell[\pos].x/width * 2 - 1);
		cell[\synth].set("verb", (cell[\pos].z/depth).clip(0,1));

	};

	zcells = cells.sort({ |cellA, cellB| cellA[\pos].z < cellB[\pos].z});

	// Draw cells
	zcells.do { |cell|
		// Darker for further away
		var blend = (cell[\pos].z/depth).clip(0,1);
		Pen.fillColor = Color.new(0.3,0.3,0.3).blend(cell[\color], blend);
		drawCell.(cell);
	};

	// Draw clouds
	if (gestureD[\HandLeft][\cloud] != nil, {
		var cloud = gestureD[\HandLeft][\cloud];
		var sc = translateCoords.(translateKinectCoords.(cloud[\pos]));
		var sqSize = (1000000 * cloud[\pos].z / depth);
		cloud[\counter] = cloud[\counter] + 1;
		Pen.fillColor = Color.white;
		Pen.alpha = cos(cloud[\counter]*(2pi)/10) + 1 / 3;
		Pen.fillOval(Rect(sc.x - sqSize/scale, sc.y - sqSize/scale, sqSize*2/scale, sqSize*2/scale));
		Pen.alpha = 1;
	});
	if (gestureD[\HandRight][\cloud] != nil, {
		var cloud = gestureD[\HandRight][\cloud];
		var sc = translateCoords.(translateKinectCoords.(cloud[\pos]));
		var sqSize = (10000 * cloud[\size] * cloud[\pos].z / depth);
		cloud[\counter] = cloud[\counter] + 1;
		Pen.fillColor = if (cloud[\type] == \Lasso, { Color.red; }, { Color.green; });
		Pen.alpha = cos(cloud[\counter]*(2pi)/10) + 1 / 3;
		Pen.fillOval(Rect(sc.x - sqSize/scale, sc.y - sqSize/scale, sqSize*2/scale, sqSize*2/scale));
		Pen.alpha = 1;
	});
};

u.mouseDownAction = {
	arg view, x, y, modifiers, buttonNumber, clickCount;
	m = RealVector2D[x,y];
};

u.mouseUpAction = {
	arg view, x, y, modifiers;
	var dist = RealVector2D[x,y].dist(m);
	var xc = m.x * scale;
	var yc = m.y * scale;
	var size = dist * 5000;
	cells = cells.add(createCell.(RealVector3D[xc, yc, depth/2], size));
};

w.view.keyDownAction = {
	arg view, char, modifiers, unicode, keycode, key;
	var ymod = 0;
	var xmod = 0;
	var cell = cells[0];
	if (char == $w, {
		ymod = 1;
	});
	if (char == $s, {
		ymod = -1;
	});
	if (char == $a, {
		xmod = -1;
	});
	if (char == $d, {
		xmod = 1;
	});
	cells.do {|cell|
		cell[\vel] = cell[\vel] + RealVector3D[xmod, ymod, 0];
	}
};

s.waitForBoot({

("ffmpeg -f jack -ac 2 -i ffmpeg -f x11grab -r 30 -s $(xwininfo -root | grep 'geometry' | awk '{print $2;}') -i :0.0 -acodec pcm_s16le -vcodec libx264 -vpre lossless_ultrafast -threads 0" +
    "/home/s/Documents/" ++ Date.getDate.bootSeconds ++ ".mkv"
        ).runInTerminal;
});

)