// Voice: record the player and play it back squeaky (the plant repeats you),
// optional speech recognition so the plant understands spoken phrases, and a
// squeaky text-to-speech voice for the plant's own lines.

import { audioContext, soundEnabled } from "./sfx.js";

const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
const MAX_RECORD_SECONDS = 6;
const PLAYBACK_RATE = 1.55;

export const canRecord = Boolean(navigator.mediaDevices?.getUserMedia && window.MediaRecorder);
const canSpeak = "speechSynthesis" in window;

let session = null;

// Starts recording. Throws if the microphone is unavailable or denied.
export async function startRecording() {
	if (session) {
		return;
	}
	const stream = await navigator.mediaDevices.getUserMedia({
		audio: { echoCancellation: true, noiseSuppression: true },
	});
	const recorder = new MediaRecorder(stream);
	const chunks = [];
	recorder.ondataavailable = (event) => {
		if (event.data.size > 0) {
			chunks.push(event.data);
		}
	};
	recorder.start();

	const current = { stream, recorder, chunks, transcript: "", recognition: null, startedAt: performance.now() };
	if (Recognition) {
		try {
			const recognition = new Recognition();
			recognition.lang = navigator.language || "en-US";
			recognition.interimResults = false;
			recognition.maxAlternatives = 1;
			recognition.onresult = (event) => {
				current.transcript = Array.from(event.results)
					.map((result) => result[0].transcript)
					.join(" ");
			};
			recognition.onerror = () => {};
			recognition.start();
			current.recognition = recognition;
		} catch {
			current.recognition = null;
		}
	}
	current.timeout = setTimeout(() => current.recorder.state === "recording" && current.recorder.stop(), MAX_RECORD_SECONDS * 1000);
	session = current;
}

export function isRecording() {
	return session !== null;
}

// Stops recording and resolves to { buffer, transcript } (buffer may be null).
export function stopRecording() {
	const current = session;
	session = null;
	if (!current) {
		return Promise.resolve(null);
	}
	clearTimeout(current.timeout);

	const recorded = new Promise((resolve) => {
		const finish = async () => {
			current.stream.getTracks().forEach((track) => track.stop());
			let buffer = null;
			try {
				const blob = new Blob(current.chunks, { type: current.recorder.mimeType });
				const ctx = audioContext();
				if (ctx && blob.size > 0) {
					buffer = await ctx.decodeAudioData(await blob.arrayBuffer());
				}
			} catch {
				buffer = null;
			}
			resolve(buffer);
		};
		if (current.recorder.state === "inactive") {
			finish();
		} else {
			current.recorder.onstop = finish;
			current.recorder.stop();
		}
	});

	const recognized = new Promise((resolve) => {
		const recognition = current.recognition;
		if (!recognition) {
			resolve();
			return;
		}
		const timer = setTimeout(resolve, 1500);
		recognition.onend = () => {
			clearTimeout(timer);
			resolve();
		};
		try {
			recognition.stop();
		} catch {
			resolve();
		}
	});

	return Promise.all([recorded, recognized]).then(([buffer]) => ({ buffer, transcript: current.transcript.trim() }));
}

// Plays a recording back sped-up and squeaky. Returns its duration in seconds.
export function playSqueaky(buffer) {
	const ctx = audioContext();
	if (!ctx || !buffer || !soundEnabled()) {
		return 0;
	}
	const source = ctx.createBufferSource();
	source.buffer = buffer;
	source.playbackRate.value = PLAYBACK_RATE;
	const gain = ctx.createGain();
	gain.gain.value = 1.4;
	source.connect(gain).connect(ctx.destination);
	source.start();
	return buffer.duration / PLAYBACK_RATE;
}

// The plant's own (squeaky) speaking voice.
export function speak(text) {
	if (!canSpeak || !soundEnabled()) {
		return;
	}
	const clean = text
		.replace(/\*[^*]*\*/g, " ")
		.replace(/[\p{Extended_Pictographic}~]/gu, " ")
		.trim();
	if (!clean || clean.replace(/[.!?\s]/g, "") === "") {
		return;
	}
	const utterance = new SpeechSynthesisUtterance(clean);
	utterance.pitch = 1.9;
	utterance.rate = 1.12;
	utterance.volume = 0.9;
	window.speechSynthesis.cancel();
	window.speechSynthesis.speak(utterance);
}
