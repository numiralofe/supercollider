(
a = {
	var pulse = LFNoise0.ar(16).range(50,250);
	var control = Duty.ar(1/pulse*4,0,Dseq([0,2,4,3,2,0],inf),2);
	var del = DemandEnvGen.ar(Dbrown(0.005,0.05,0.005),Dseq([2,2,4,1,1,1,1],inf));
	var src1 = Blip.ar(pulse!2,control,0.25) ring4: Hasher.ar(LFSaw.ar(1,0,100).abs);
	var src2 = Blip.ar((pulse*4.rand)!2,control+2,0.25) ring4: Hasher.ar(LFSaw.ar(2,0,100).abs);
	var src3 = Blip.ar((pulse*4.rand)!2,control+3,0.25) ring4: Hasher.ar(LFSaw.ar(3,0,100).abs);
	var src4 = Blip.ar((pulse*4.rand)!2,control+4,0.25) ring4: Hasher.ar(LFSaw.ar(4,0,100).abs);
	var out = src1+src2+src3+src4*LFPulse.ar(pulse*2,0,0.5,0.75,0.25);
	out ring3: Splay.arFill(16,{HenonC.ar([rrand(300,15000),rrand(300,15000)],rrand(1.0,1.4))})
}
)

~aPlayer = a.play;
~aPlayer.free;

b = {a=HPF.ar(ar(PinkNoise,5e-3),10)*Line.kr(0,1,9);ar(GVerb,({|i|ar(Ringz,a*LFNoise1.kr(0.05+0.1.rand),55*i+60,0.2)}!99).sum,70,99).tanh}

~bPlayer = b.play;
~bPlayer.free;

(
~dark = Ndef(\x,	{
		var output;
		var delayTime;
		var delayMax = 0.2;
		var delayAdd = 0.1;
		var pulseFreq = 0.5;
		var proxyMul = 2;
		var pulseMin = 40;
		var pulseMax = 130;
		var numOfEchos = 2;

		var mainPulse = LFPulse.ar(pulseFreq, 0, 0.5).range(pulseMin, pulseMax);
		var proxy = Ndef(\x).ar * proxyMul;
		var ampModFreq = SinOsc.ar(0.01, 0).range(0.3, 30);
		var ampMod = LFNoise1.ar(ampModFreq, 6);
		output = SinOsc.ar(mainPulse + proxy, 0, ampMod).tanh;
		numOfEchos.do{
			delayTime = {delayMax.rand + delayAdd}!2;
			output = AllpassL.ar(output, 0.1, delayTime, 5);
		};
	output.tanh;
	})
)

~cPlayer = ~dark.play;
~cPlayer.stop;


(
{ | dur = 0.10, atk = 0.005, amp = 1 |
	SinOsc.ar(
		EnvGen.ar( Env(
			NamedControl.kr(\freq_l, [2960, 70, 90]),
			NamedControl.kr(\freq_d, [0.07, 0.2]),
			NamedControl.kr(\freq_c, [-13, -1]),
		) ),
		mul:amp * EnvGen.ar(
			Env.perc( atk, dur - atk, curve: NamedControl.kr(\amp_c, [-1, 6])),
			doneAction: 2
		);
	) ! 2;
}.asSynthDef.name_("kick").add;

{ | atk = 0.01, dur = 0.15, freq = 50, amp=0.8 |
	BPF.ar(LFSaw.ar(freq), freq, 2, mul: EnvGen.kr( Env.perc( atk, dur-atk, amp, 6 ), doneAction: 2 )) ! 2;
}.asSynthDef.name_("bass").add;

{ | dur = 0.15, freq = 50, amp = 0.8, index = 10 |
	PMOsc.ar(freq, freq + 5, index, mul: amp * EnvGen.kr( Env.triangle( dur ), doneAction: 2 )) ! 2;
}.asSynthDef.name_("bazz").add;
)


(
~beat = Ppar([
	Pbind(*[
		instrument: \kick,
		delta: 1,
		dur: Pfunc({ thisThread.clock.beatDur }) / 4,
		amp: Pseq([
			Pseq([1], 16),
			Pseq([0.8, 1], 8),
			Pseq([1], 16),
			Pseq([0.8, 0.8, 0.9, 1], 8)
		], inf) * 0.8,
		freq_l: Pstutter(Prand(2.pow((1..4)),inf), Pseq([
			`[2960,70,90],
			`[1260,60,110],
			`[4360,60,120]
		],inf))
	]),
	Pbind(*[
		instrument: \bass,
		delta: 1/4,
		dur: Pkey(\delta) * Pfunc({ thisThread.clock.beatDur }),
		freq: Pseq([\r, 50,60,70], inf),
		amp:0.6
	]),
	Pbind(*[
		instrument: \bazz,
		delta: 1/4,
		dur: Pkey(\delta) * Pfunc({ thisThread.clock.beatDur }),
		freq: Pseq([\r, 30,35,40], inf),
		amp:0.2
	])
])
)

~dPlayer = ~beat.play(TempoClock(100/60), quant:[1])
~ePlayer = ~beat.play(TempoClock(130/60), quant:[1])

~dPlayer.stop;
~ePlayer.stop;


// Start bass base line

SynthDef(\daf_bass,{ |out, freq=440, sustain=1, gate=1, amp=0.1|
	var snd, env, fenv, harm;
	harm = [1,1.01,2,2.02,3.5,4.01,5.501];
	harm = harm ++ (harm*2);
	snd = SinOsc.ar(freq*harm).sum.distort * 2;
	snd = snd + SinOsc.ar(freq / [1, 2]).sum!2;
	env = EnvGen.kr(Env.adsr(0.001,0.2,0.9,0.25), gate, amp, doneAction:2);
	snd = snd * env;
	OffsetOut.ar(out, (snd!2));
}).add;

(
~bassline = Pdef(\daf_bass,
	Pbind(
		\instrument, \daf_bass,
		\scale, Scale.minor,
		\octave, [3], // try out [2,3] or [3,4] for octave bass leetness
		\ctranspose,Pseq([
			Pn(-1,16*4),
			Pn(1,16*2)
		], inf),
		// -1 for thinking in musical degrees...
		\degree, Pseq([1, 4, 1, 10, 1, 8, 1, 1, 8, 1, 8, 1, 8, 7, 1, 8]-1,inf),
		\legato, Pwhite(0.75, 0.8),
		\dur, 0.2
	)
)
)

~fPlayer = ~bassline.play(TempoClock(43/60), quant:[1])
~gPlayer = ~bassline.play(TempoClock(63/60), quant:[1])

~fPlayer.stop;
~gPlayer.stop;