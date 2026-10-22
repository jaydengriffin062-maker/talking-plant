// Tiny helper for building SVG elements.

const NS = "http://www.w3.org/2000/svg";

export function el(tag, attrs = {}, children = []) {
	const node = document.createElementNS(NS, tag);
	for (const [key, value] of Object.entries(attrs)) {
		if (value !== undefined && value !== null) {
			node.setAttribute(key, String(value));
		}
	}
	for (const child of children) {
		node.appendChild(child);
	}
	return node;
}

// Sets attributes only when they changed (cheap per-frame updates).
export function set(node, attrs) {
	const cache = (node._attrCache ??= {});
	for (const [key, value] of Object.entries(attrs)) {
		const text = String(value);
		if (cache[key] !== text) {
			cache[key] = text;
			node.setAttribute(key, text);
		}
	}
}

export const fmt = (n) => (Math.round(n * 100) / 100).toString();
